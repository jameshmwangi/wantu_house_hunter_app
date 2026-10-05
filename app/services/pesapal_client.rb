# frozen_string_literal: true

require "faraday"

# HTTP client for the Pesapal API 3.0.
#
# Based on the official Pesapal PHP reference (development1/PesaPal-main).
#
# URL structure (confirmed from reference):
#   Sandbox base : https://cybqa.pesapal.com/pesapalv3
#   Live base    : https://pay.pesapal.com/v3
#   All endpoints: {base}/api/{path}
#
# Flow:
#   1. POST /api/Auth/RequestToken           → token
#   2. POST /api/URLSetup/RegisterIPN        → ipn_id (one-time, store in PESAPAL_IPN_ID)
#   3. POST /api/Transactions/SubmitOrderRequest → redirect_url + order_tracking_id
#   4. Show redirect_url to user in iframe / full redirect
#   5. Pesapal POSTs IPN to your endpoint with: OrderTrackingId, OrderMerchantReference, OrderNotificationType
#   6. GET  /api/Transactions/GetTransactionStatus?orderTrackingId=... → status_code
#
# IPN payload (from pin.json reference):
#   { "OrderTrackingId": "...", "OrderNotificationType": "IPNCHANGE", "OrderMerchantReference": "..." }
#
# Browser callback (GET from Pesapal after payment):
#   ?OrderTrackingId=...&OrderMerchantReference=...&OrderNotificationType=CALLBACKURL
class PesapalClient
  class PesapalError < StandardError; end

  def initialize
    @config = Rails.application.config.pesapal
    @conn   = Faraday.new do |f|
      f.request  :json
      f.response :json, content_type: /\bjson$/
      f.adapter  Faraday.default_adapter
    end
  end

  # ─── Step 1: Auth ─────────────────────────────────────────────────────────
  # POST /api/Auth/RequestToken
  # No Authorization header needed — uses consumer_key + consumer_secret in body.
  # Token expires in 5 minutes; cache for 4 minutes to stay safe.

  def token
    Rails.cache.fetch("pesapal:token:#{@config[:environment]}", expires_in: 4.minutes) do
      response = @conn.post(endpoint("/api/Auth/RequestToken")) do |req|
        req.headers["Accept"]       = "application/json"
        req.headers["Content-Type"] = "application/json"
        req.body = {
          consumer_key:    @config[:consumer_key],
          consumer_secret: @config[:consumer_secret]
        }
      end

      key_mask    = Pesapal.mask_val(@config[:consumer_key])
      secret_mask = Pesapal.mask_val(@config[:consumer_secret])

      # Log the full auth response with credential fingerprints so mismatches are diagnosable
      Rails.logger.info "[PesapalClient#token] status=#{response.status} env=#{@config[:environment]} " \
                        "base_url=#{Pesapal.base_url} key=#{key_mask} secret=#{secret_mask} body=#{response.body.inspect}"

      if response.status == 302
        location = response.headers["location"] || "(no Location header)"
        raise PesapalError,
              "Auth returned 302 redirect → #{location}. " \
              "PESAPAL_ENV=#{@config[:environment]} does not match your credentials. " \
              "Sandbox keys → PESAPAL_ENV=sandbox, live keys → PESAPAL_ENV=production."
      end

      body = response.body
      unless response.success? && body.is_a?(Hash) && body["token"].present?
        # Dump the entire body — Pesapal returns 200 even for bad credentials,
        # and the error can be in "error", "message", "status", or other fields.
        raise PesapalError, "Auth failed (#{response.status}) [key=#{key_mask} secret=#{secret_mask}]: #{body.inspect}"
      end

      body["token"]
    end
  end

  # ─── Step 2: Register IPN (one-time setup) ─────────────────────────────────
  # POST /api/URLSetup/RegisterIPN
  # Authorization: Bearer {token}
  # Body: { "url": "...", "ipn_notification_type": "POST" }
  # Returns: { "ipn_id": "...", "url": "...", ... }
  # Store ipn_id as PESAPAL_IPN_ID env var — pass it as notification_id on every order.

  def register_ipn(ipn_url:)
    response = authed_post("/api/URLSetup/RegisterIPN", {
      url:                   ipn_url,
      ipn_notification_type: "POST"
    })

    ipn_id = response["ipn_id"]
    raise PesapalError, "IPN registration returned no ipn_id: #{response.inspect}" if ipn_id.blank?

    ipn_id
  end

  # List all registered IPN URLs for your account.
  # GET /api/URLSetup/GetIpnList
  def get_ipn_list
    authed_get("/api/URLSetup/GetIpnList")
  end

  # ─── Step 3: Submit Order ──────────────────────────────────────────────────
  # POST /api/Transactions/SubmitOrderRequest
  # Authorization: Bearer {token}
  #
  # Required: id (merchant_reference), currency, amount (Float), description,
  #           callback_url, notification_id (ipn_id), billing_address
  # billing_address needs at least phone_number OR email_address.
  #
  # Returns: { "order_tracking_id": "...", "merchant_reference": "...", "redirect_url": "..." }
  #
  # @param merchant_reference [String] unique per attempt, max 50 chars, alphanumeric + - _ . :
  # @param amount [Float] e.g. 500.0 (NOT a string)
  # @param description [String]
  # @param callback_url [String] browser redirect-back after payment
  # @param phone_number [String] e.g. "0768168060"
  # @param email_address [String]
  # @param first_name [String]
  # @param middle_name [String]
  # @param last_name [String]
  # @param currency [String] "KES" or "UGX"
  # @param branch [String] optional merchant branch name
  # @return [Hash] { order_tracking_id:, merchant_reference:, redirect_url: }

  def submit_order(merchant_reference:, amount:, description:, callback_url:,
                   phone_number: nil, email_address: nil,
                   first_name: "", middle_name: "", last_name: "",
                   currency: "KES", branch: "")
    notification_id = @config[:ipn_id]
    raise PesapalError, "PESAPAL_IPN_ID is not set — run register_ipn first and store the result" if notification_id.blank?

    billing_address = {
      country_code: currency == "UGX" ? "UG" : "KE",
      first_name:   first_name,
      middle_name:  middle_name,
      last_name:    last_name,
      line_1:       "",
      line_2:       "",
      city:         "",
      state:        "",
      postal_code:  "",
      zip_code:     ""
    }
    billing_address[:phone_number]  = phone_number    if phone_number.present?
    billing_address[:email_address] = email_address   if email_address.present?

    body = {
      id:              merchant_reference,
      currency:        currency,
      amount:          amount.to_f,
      description:     description,
      callback_url:    callback_url,
      notification_id: notification_id,
      branch:          branch,
      billing_address: billing_address
    }

    Rails.logger.info "[PesapalClient#submit_order] REQUEST body: #{body.to_json}"

    response = authed_post("/api/Transactions/SubmitOrderRequest", body)

    Rails.logger.info "[PesapalClient#submit_order] RESPONSE: #{response.inspect}"

    {
      order_tracking_id:  response["order_tracking_id"],
      merchant_reference: response["merchant_reference"],
      redirect_url:       response["redirect_url"]
    }
  end

  # ─── Step 6: Get Transaction Status ────────────────────────────────────────
  # GET /api/Transactions/GetTransactionStatus?orderTrackingId={id}
  # Authorization: Bearer {token}
  #
  # Called after IPN fires or browser callback lands — never trust IPN arrival alone.
  #
  # status_code meaning:
  #   0 → INVALID (not yet final, keep waiting)
  #   1 → COMPLETED (success — payment received)
  #   2 → FAILED
  #   3 → REVERSED (treat as failed)
  #
  # @param order_tracking_id [String] the UUID returned by submit_order
  # @return [Hash] raw Pesapal response body

  def get_transaction_status(order_tracking_id)
    response = @conn.get(endpoint("/api/Transactions/GetTransactionStatus")) do |req|
      req.headers["Authorization"] = "Bearer #{token}"
      req.headers["Accept"]        = "application/json"
      req.headers["Content-Type"]  = "application/json"
      req.params["orderTrackingId"] = order_tracking_id
    end

    unless response.success?
      raise PesapalError, "GetTransactionStatus failed (#{response.status}): #{response.body["message"]}"
    end

    response.body
  end

  private

  def endpoint(path)
    base = Pesapal.base_url.chomp("/")
    p = path.sub(%r{\A/}, "")
    "#{base}/#{p}"
  end

  def authed_post(path, body)
    response = @conn.post(endpoint(path)) do |req|
      req.headers["Authorization"] = "Bearer #{token}"
      req.headers["Accept"]        = "application/json"
      req.headers["Content-Type"]  = "application/json"
      req.body = body
    end

    # A 302 typically means sandbox credentials hitting the production URL
    # (or vice versa). Pesapal redirects to a login/error page instead of
    # returning JSON — surface this clearly so it's easy to diagnose.
    if response.status == 302
      location = response.headers["location"] || "(no Location header)"
      raise PesapalError,
            "Pesapal returned 302 redirect on #{path} → #{location}. " \
            "This usually means PESAPAL_ENV (#{@config[:environment]}) does not match your credentials. " \
            "Sandbox keys must use PESAPAL_ENV=sandbox, live keys must use PESAPAL_ENV=production."
    end

    unless response.success?
      err_body = response.body.is_a?(Hash) ? (response.body["message"] || response.body.inspect) : response.body.to_s.first(500)
      raise PesapalError, "Pesapal error on #{path} (#{response.status}): #{err_body}"
    end

    response.body
  end

  def authed_get(path, params = {})
    response = @conn.get(endpoint(path)) do |req|
      req.headers["Authorization"] = "Bearer #{token}"
      req.headers["Accept"]        = "application/json"
      req.headers["Content-Type"]  = "application/json"
      req.params.merge!(params) if params.any?
    end

    unless response.success?
      raise PesapalError, "Pesapal error on #{path} (#{response.status}): #{response.body["message"] || response.body.inspect}"
    end

    response.body
  end
end
