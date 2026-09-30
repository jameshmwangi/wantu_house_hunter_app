# Provider-neutral gateway adapter.
#
# Delegates to PesapalClient when Pesapal credentials are present
# (PESAPAL_CONSUMER_KEY + PESAPAL_CONSUMER_SECRET + PESAPAL_IPN_ID set in env).
# Falls back to simulation mode when credentials are absent — useful in
# development and test without real sandbox keys.
#
# IMPORTANT — Pesapal flow differs from a direct STK push:
#   initiate_collection returns a :redirect_url that must be shown to the user
#   (in an iframe or as a full redirect). The actual M-Pesa push is triggered
#   by Pesapal's hosted page — NOT by your server directly.
#
# Payment field name reference from PesaPal-main PHP:
#   billing_address: phone_number, email_address, first_name, middle_name, last_name,
#                    country_code, line_1, city, state, postal_code, zip_code
#   order fields: id (merchant_reference), currency, amount (Float), description,
#                 callback_url, notification_id, branch
class PaymentGatewayAdapter
  class Error < StandardError; end

  SimulationResult = Struct.new(:status, :provider_reference, keyword_init: true)

  # Initiate a collection (home seeker pays the view fee via Pesapal hosted page).
  #
  # Returns a hash with :provider_reference (order_tracking_id), :status, :redirect_url
  # The caller MUST surface redirect_url to the user (iframe or full redirect).
  #
  # @param escrow_transaction [EscrowTransaction]
  # @param home_seeker [User]
  # @param callback_url [String] browser redirect-back URL (GET with OrderTrackingId param)
  # @return [Hash] { provider:, provider_reference:, merchant_reference:, status:, redirect_url: }
  def initiate_collection(escrow_transaction, home_seeker:, callback_url:, phone_number: nil)
    return simulate_collection(escrow_transaction) unless Pesapal.configured?

    client = PesapalClient.new

    # Merchant reference: unique per attempt, max 50 chars, alphanumeric + - _ . :
    merchant_reference = "BOOKING-#{escrow_transaction.id}-#{SecureRandom.hex(4)}"
    amount   = escrow_transaction.amount_cents / 100.0
    currency = escrow_transaction.currency

    # Parse first and last names from user's full name
    name_parts = (home_seeker.full_name || "").strip.split(/\s+/, 2)
    first_name = name_parts[0].presence || "Valued"
    last_name  = name_parts[1].presence || "Customer"
    contact_phone = phone_number.presence || home_seeker.phone_number.to_s

    result = client.submit_order(
      merchant_reference: merchant_reference,
      amount:             amount,
      description:        "Wantu view fee",
      callback_url:       callback_url,
      phone_number:       contact_phone,
      email_address:      home_seeker.email.to_s,
      first_name:         first_name,
      middle_name:        "",
      last_name:          last_name,
      currency:           currency,
      branch:             "Wantu House Hunter"
    )

    {
      provider:           "pesapal",
      provider_reference: result[:order_tracking_id],   # UUID — used to look up status
      merchant_reference: merchant_reference,
      status:             "pending",
      redirect_url:       result[:redirect_url]
    }
  rescue PesapalClient::PesapalError => e
    raise Error, e.message
  end

  # Initiate a payout to an agent's mobile wallet.
  # Pesapal API 3.0 is primarily a collection gateway; disbursements require a
  # separate product. Until that is available, falls back to simulation.
  #
  # @param withdrawal [Withdrawal]
  # @param callback_url [String] placeholder for future disbursement API
  def initiate_payout(withdrawal, callback_url:)
    Rails.logger.warn "[PaymentGatewayAdapter] Pesapal disbursement not yet integrated — simulation fallback"
    simulate_payout(withdrawal)
  end

  # Server-to-server transaction status check (used by ReconcilePendingPaymentsJob).
  # Calls GetTransactionStatus?orderTrackingId={provider_reference}.
  #
  # Returns the raw Pesapal response body. Key field: "status_code"
  #   0 = INVALID/pending, 1 = COMPLETED, 2 = FAILED, 3 = REVERSED
  #
  # @param provider_reference [String] the order_tracking_id stored on PaymentTransaction
  # @param country_code [String] unused (kept for interface compatibility)
  # @return [Hash] raw Pesapal GetTransactionStatus response
  def verify_transaction(provider_reference, country_code: "KE")
    return { "status_code" => 0, "payment_status_description" => "SIMULATED" } unless Pesapal.configured?

    PesapalClient.new.get_transaction_status(provider_reference)
  rescue PesapalClient::PesapalError => e
    raise Error, e.message
  end

  # Extract the order_tracking_id from a Pesapal IPN payload.
  # IPN body (confirmed from pin.json reference):
  #   { "OrderTrackingId": "...", "OrderNotificationType": "IPNCHANGE", "OrderMerchantReference": "..." }
  #
  # @param payload [Hash] raw IPN params
  # @return [String, nil]
  def extract_order_tracking_id(payload)
    payload["OrderTrackingId"]  ||
      payload[:OrderTrackingId] ||
      payload["orderTrackingId"]
  end

  private

  def simulate_collection(escrow_transaction)
    Rails.logger.info "[PaymentGatewayAdapter] SIMULATION — collection for escrow ##{escrow_transaction.id}"
    {
      provider:           "simulation",
      provider_reference: "SIM-#{SecureRandom.hex(6)}",
      merchant_reference: "SIM-BOOKING-#{escrow_transaction.id}",
      status:             "simulated",
      redirect_url:       nil
    }
  end

  def simulate_payout(withdrawal)
    Rails.logger.info "[PaymentGatewayAdapter] SIMULATION — payout for withdrawal ##{withdrawal.id}"
    { provider: "simulation", provider_reference: "SIM-#{SecureRandom.hex(6)}", status: "simulated" }
  end
end
