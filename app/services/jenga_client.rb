# frozen_string_literal: true

require "faraday"

# HTTP client for the Jenga API (Equity Bank / Finserve Africa).
#
# Covers:
#   - Kenya  : M-Pesa STK Push collection  (initiate_mpesa_stk_push)
#   - Kenya  : Mobile Wallet payout        (send_to_mobile_wallet)
#   - Uganda : MTN MoMo / Airtel payout    (send_to_mobile_wallet, UG routing)
#
# Authentication is two-part (both required on money-moving endpoints):
#   1. Bearer token  — obtained from merchant credentials, cached 50 min.
#   2. Signature header — RSA-SHA256 over endpoint-specific fields (JengaSigner).
#
# All collection and payout operations are asynchronous: the initiation call
# returns code -1 ("await final status on callback"). Actual outcomes arrive
# via IPN webhooks registered in JengaHQ -> Settings -> IPNs.
#
# See design doc §3–§5 and config/initializers/jenga.rb for setup instructions.
class JengaClient
  class JengaError < StandardError; end

  def initialize
    @config = Rails.application.config.jenga
    @signer = JengaSigner.new(private_key_pem: @config[:private_key])
    @conn   = Faraday.new(url: Jenga.base_url) do |f|
      f.request  :json
      f.response :json, content_type: /\bjson$/
      f.adapter  Faraday.default_adapter
    end
  end

  # ─── Auth ───────────────────────────────────────────────────────────────────

  # Obtain a Bearer token, cached for 50 minutes.
  # The token endpoint does NOT require a Signature header.
  #
  # Jenga response fields: accessToken, refreshToken, expiresIn (ISO8601 timestamp),
  # issuedAt, tokenType.
  def token
    Rails.cache.fetch("jenga:token:#{@config[:environment]}", expires_in: 50.minutes) do
      response = @conn.post("/authentication/api/v3/authenticate/merchant") do |req|
        req.headers["Content-Type"] = "application/json"
        req.headers["Api-Key"]      = @config[:api_key] # goes in the header, not the body
        req.body = {
          merchantCode:   @config[:merchant_code],
          consumerSecret: @config[:consumer_secret]
        }
      end
      raise JengaError, "Auth failed: #{response.body["message"]}" unless response.success?

      response.body["accessToken"]
    end
  end

  # ─── Collection: Kenya M-Pesa STK Push ──────────────────────────────────────

  # Initiates an M-Pesa STK Push for a Kenya escrow transaction.
  # The response merely acknowledges acceptance (code -1). The real result
  # arrives via the IPN registered at JengaHQ -> Settings -> IPNs.
  #
  # Signature field order (M-Pesa STK Push):
  #   orderReference + paymentCurrency + msisdn + paymentAmount
  #
  # @param escrow_transaction [EscrowTransaction]
  # @param home_seeker [User]
  # @param callback_url [String] your unified IPN endpoint, e.g. https://wantu.onrender.com/api/v1/payments/jenga_ipn
  # @return [Hash] Jenga response merged with generated references
  def initiate_mpesa_stk_push(escrow_transaction:, home_seeker:, callback_url:)
    order_reference   = "OR-#{escrow_transaction.id}-#{SecureRandom.hex(3)}"
    payment_reference = "PR-#{escrow_transaction.id}-#{SecureRandom.hex(3)}"
    amount            = (escrow_transaction.amount_cents / 100.0).to_s

    signature = @signer.sign(
      order_reference,
      escrow_transaction.currency,
      home_seeker.phone_number,
      amount
    )

    response = signed_post("/api-checkout/mpesa-stk-push/v3.0/init", signature, {
      order: {
        orderReference: order_reference,
        orderAmount:    escrow_transaction.amount_cents / 100.0,
        orderCurrency:  escrow_transaction.currency,
        source:         "APICHECKOUT",
        countryCode:    escrow_transaction.country,
        description:    "Wantu view fee"
      },
      customer: {
        name:           home_seeker.full_name,
        email:          home_seeker.email,
        phoneNumber:    home_seeker.phone_number,
        identityNumber: "0000000" # national ID optional; supply if available on the User model
      },
      payment: {
        paymentReference: payment_reference,
        paymentCurrency:  escrow_transaction.currency,
        channel:          "MOBILE",
        service:          "MPESA",
        provider:         "JENGA",
        callbackUrl:      callback_url,
        details: {
          msisdn:        home_seeker.phone_number,
          paymentAmount: escrow_transaction.amount_cents / 100.0
        }
      }
    })

    response.merge("order_reference" => order_reference, "payment_reference" => payment_reference)
  end

  # ─── Payout: Send Money to a Mobile Wallet (KE + UG) ────────────────────────

  # Initiates a payout to an agent's mobile wallet (M-Pesa, MTN MoMo, or Airtel Money).
  # Also async: accept callback or poll query_transaction for the final result.
  #
  # Signature field order (Send Money -> Mobile Wallets):
  #   transfer.amount + transfer.currencyCode + transfer.reference + source.accountNumber
  #
  # @param withdrawal [Withdrawal]
  # @param payout_account [PayoutAccount]
  # @param callback_url [String] your unified IPN endpoint, e.g. https://wantu.onrender.com/api/v1/payments/jenga_ipn
  # @return [Hash] Jenga response merged with generated reference
  def send_to_mobile_wallet(withdrawal:, payout_account:, callback_url:)
    reference = "WD-#{withdrawal.id}-#{SecureRandom.hex(3)}"
    currency  = payout_account.country == "UG" ? "UGX" : "KES"
    amount    = (withdrawal.amount_cents / 100.0).to_s

    signature = @signer.sign(
      amount,
      currency,
      reference,
      @config[:source_account]
    )

    # walletName routing: Jenga expects "Mpesa", "Airtel", or "MTN"
    wallet_name = case payout_account.kind
                  when "mpesa"       then "Mpesa"
                  when "momo"        then "MTN"
                  when "airtel_money" then "Airtel"
                  else payout_account.kind.capitalize
                  end

    response = signed_post("/v3-apis/transaction-api/v3.0/remittance/sendmobile", signature, {
      source: {
        countryCode:   payout_account.country,
        name:          "Wantu House Hunter",
        accountNumber: @config[:source_account]
      },
      destination: {
        type:         "mobile",
        countryCode:  payout_account.country,
        name:         withdrawal.agent.full_name,
        mobileNumber: payout_account.details,
        walletName:   wallet_name
      },
      transfer: {
        type:         "MobileWallet",
        amount:       amount,
        currencyCode: currency,
        reference:    reference,
        date:         Date.current.iso8601,
        description:  "Wantu agent payout",
        callbackUrl:  callback_url
      }
    })

    response.merge("reference" => reference)
  end

  # ─── Query (reconciliation) ───────────────────────────────────────────────────

  # Server-to-server transaction status check.
  # Used by ReconcilePendingPaymentsJob for payments stuck in "pending".
  # Never rely on callbacks alone — always have a reconciliation path.
  #
  # @param provider_reference [String] the paymentReference / transfer.reference
  # @param country_code [String] "KE" or "UG"
  # @return [Hash] Jenga response body
  def query_transaction(provider_reference:, country_code: "KE")
    response = @conn.get(
      "/v3-apis/transaction-api/v3.0/query/reference/#{country_code}/#{provider_reference}"
    ) do |req|
      req.headers["Authorization"] = "Bearer #{token}"
      req.headers["Content-Type"]  = "application/json"
    end
    raise JengaError, "Query failed: #{response.body["message"]}" unless response.success? || response.body.is_a?(Hash)

    response.body
  end

  private

  # POST with Authorization + Signature headers.
  def signed_post(path, signature, body)
    response = @conn.post(path) do |req|
      req.headers["Content-Type"]  = "application/json"
      req.headers["Authorization"] = "Bearer #{token}"
      req.headers["Signature"]     = signature
      req.body = body
    end

    # Jenga returns 200 with code: -1 on async acceptance; treat as success.
    # Only raise if the HTTP status itself is an error AND the body has a message.
    unless response.success? || response.body.dig("status")
      raise JengaError, "Jenga error (#{response.status}): #{response.body["message"]}"
    end

    response.body
  end
end
