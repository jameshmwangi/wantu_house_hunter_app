# Provider-neutral gateway adapter.
#
# Delegates to JengaClient when Jenga credentials are present (JENGA_API_KEY +
# JENGA_PRIVATE_KEY set in env). Falls back to simulation mode when credentials
# are absent — useful in development and test without real sandbox keys.
#
# This adapter is the seam between domain logic (EscrowTransaction, Withdrawal)
# and the payment provider. Swap the inner implementation without touching models.
class PaymentGatewayAdapter
  SimulationResult = Struct.new(:status, :provider_reference, keyword_init: true)

  # Initiate a collection (home seeker pays the view fee).
  # For Kenya:  M-Pesa STK Push via JengaClient#initiate_mpesa_stk_push.
  # For Uganda: MTN MoMo / Airtel — same client, country routing via EscrowTransaction#country.
  # Returns a hash with at least :provider_reference and :status keys.
  #
  # @param escrow_transaction [EscrowTransaction]
  # @param home_seeker [User]
  # @param callback_url [String] IPN URL registered in JengaHQ
  def initiate_collection(escrow_transaction, home_seeker:, callback_url:)
    return simulate_collection(escrow_transaction) unless Jenga.configured?

    client = JengaClient.new

    case escrow_transaction.country
    when "KE"
      result = client.initiate_mpesa_stk_push(
        escrow_transaction: escrow_transaction,
        home_seeker:        home_seeker,
        callback_url:       callback_url
      )
      { provider: "jenga", provider_reference: result["payment_reference"], status: "pending" }
    when "UG"
      # Uganda collection uses the same JengaClient with country routing.
      # Jenga's Uganda mobile money collection endpoint will be wired here once
      # Finserve confirms the exact UG collection endpoint (currently using KE
      # as the template — verify with Jenga docs before enabling for UG).
      raise NotImplementedError, "Uganda collection endpoint — confirm with Finserve and wire here"
    else
      raise ArgumentError, "Unsupported country: #{escrow_transaction.country}"
    end
  end

  # Initiate a payout to an agent's mobile wallet.
  # Covers M-Pesa (KE), MTN MoMo (UG), and Airtel Money (UG).
  # Returns a hash with :provider_reference and :status keys.
  #
  # @param withdrawal [Withdrawal]
  # @param callback_url [String] payout IPN URL registered in JengaHQ
  def initiate_payout(withdrawal, callback_url:)
    return simulate_payout(withdrawal) unless Jenga.configured?

    client  = JengaClient.new
    account = withdrawal.payout_account

    result = client.send_to_mobile_wallet(
      withdrawal:    withdrawal,
      payout_account: account,
      callback_url:  callback_url
    )

    { provider: "jenga", provider_reference: result["reference"], status: "pending" }
  end

  # Server-to-server transaction status query (used by ReconcilePendingPaymentsJob).
  #
  # @param provider_reference [String]
  # @param country_code [String] "KE" or "UG"
  # @return [Hash] raw Jenga query response
  def verify_transaction(provider_reference, country_code: "KE")
    return { status: "simulated" } unless Jenga.configured?

    JengaClient.new.query_transaction(
      provider_reference: provider_reference,
      country_code:       country_code
    )
  end

  # Verify an incoming IPN webhook payload against the provider's expected signature.
  # Jenga uses HMAC or RSA verification depending on the endpoint — implement once
  # Finserve confirms the exact IPN signature method for sandbox.
  #
  # @param payload [Hash]
  # @param signature [String] value of the Jenga-Signature header
  def handle_webhook(payload, signature)
    return { status: "simulated" } unless Jenga.configured?

    # TODO: implement Jenga IPN signature verification once the exact
    # algorithm is confirmed with Finserve support (HMAC-SHA256 or RSA).
    # For now, trust the payload and let the IPN controller handle logic.
    payload
  end

  private

  def simulate_collection(escrow_transaction)
    Rails.logger.info "[PaymentGatewayAdapter] SIMULATION — collection for escrow ##{escrow_transaction.id}"
    { provider: "simulation", provider_reference: "SIM-#{SecureRandom.hex(6)}", status: "simulated" }
  end

  def simulate_payout(withdrawal)
    Rails.logger.info "[PaymentGatewayAdapter] SIMULATION — payout for withdrawal ##{withdrawal.id}"
    { provider: "simulation", provider_reference: "SIM-#{SecureRandom.hex(6)}", status: "simulated" }
  end
end
