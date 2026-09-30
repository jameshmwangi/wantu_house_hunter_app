# frozen_string_literal: true

require "openssl"
require "base64"
require "securerandom"
require "bigdecimal"

# Jenga API (Equity Bank / Finserve Africa) configuration.
# Covers Kenya (M-Pesa STK Push) and Uganda (MTN MoMo / Airtel Money) under one integration.
#
# Required environment variables:
#   JENGA_ENV             — "sandbox" or "production"
#   JENGA_API_KEY         — from JengaHQ dashboard
#   JENGA_MERCHANT_CODE   — from JengaHQ dashboard
#   JENGA_CONSUMER_SECRET — from JengaHQ dashboard
#   JENGA_PRIVATE_KEY     — contents of private_key.pem (RSA 2048, PKCS#8), never commit this
#   JENGA_SOURCE_ACCOUNT  — Jenga-linked account number. For STK push this is the account
#                           credited on payment completion (merchant.accountNumber);
#                           also used as the disbursement account for payouts.
#   JENGA_IPN_USERNAME    — HTTP Basic Auth username for Jenga IPN callbacks
#   JENGA_IPN_PASSWORD    — HTTP Basic Auth password for Jenga IPN callbacks
#
# Key generation (one-time per environment, sandbox and production must use separate pairs):
#   openssl genpkey -algorithm RSA -out private_key.pem -pkeyopt rsa_keygen_bits:2048
#   openssl rsa -pubout -in private_key.pem -out public_key.pem
#   # Upload public_key.pem to JengaHQ -> Keys
#   # Store private_key.pem contents in JENGA_PRIVATE_KEY env var
#
# IPN / callback handling:
#   JengaHQ -> Settings -> IPNs:
#     https://<domain>/api/v1/payments/jenga_ipn
#   (Jenga only allows one IPN per environment.)
#   Set your chosen Basic Auth credentials in JENGA_IPN_USERNAME and JENGA_IPN_PASSWORD.
#
#   NOTE: STK push refs (payment.ref) are limited to 6 alphanumeric characters, so they
#   cannot carry an "OR-"/"PR-" prefix. Use Jenga.generate_reference for the STK push ref,
#   store it on the payment record (unique index, e.g. payments.jenga_reference), and have
#   the IPN handler find the record by looking up the callback's transactionReference.
#   Dispatch collections vs payouts by which table the reference is found in, not by prefix.
#   Payout (WD-) references belong to a different Jenga API; check its own reference limits.

module Jenga
  # Hosts only. Endpoint paths live in the constants below so every Jenga call
  # (auth, STK push, status, ...) can share the same base URL.
  BASE_URLS = {
    "sandbox"    => "https://uat.finserve.africa",
    "production" => "https://api.finserve.africa"
  }.freeze

  # Verify AUTH_PATH against the Authentication page in the Jenga docs.
  AUTH_PATH     = "/authentication/api/v3/authenticate/merchant"
  STK_PUSH_PATH = "/v3-apis/payment-api/v3.0/stkussdpush/initiate"

  # Docs example contains the typo "Safafricom"; the callback uses "Safaricom".
  TELCO_SAFARICOM = "Safaricom"

  # payment.ref: up to 6 alphanumeric characters (per current docs).
  REFERENCE_LENGTH   = 6
  REFERENCE_ALPHABET = [*"A".."Z", *"0".."9"].freeze

  def self.base_url
    BASE_URLS.fetch(Rails.application.config.jenga[:environment])
  end

  def self.auth_url
    "#{base_url}#{AUTH_PATH}"
  end

  def self.stk_push_url
    "#{base_url}#{STK_PUSH_PATH}"
  end

  # Returns true when the Jenga integration is fully configured with real credentials.
  # Falls back to simulation mode when credentials are absent or still set to placeholders
  # (development/test). A real PEM key always contains "BEGIN".
  def self.configured?
    api_key     = Rails.application.config.jenga[:api_key]
    private_key = Rails.application.config.jenga[:private_key]

    api_key.present? &&
      !api_key.start_with?("your_") &&
      private_key.present? &&
      private_key.include?("BEGIN")
  end

  # Random 6-char uppercase alphanumeric reference (~2.1 billion combinations).
  # Callers MUST persist it under a unique DB index and retry with a new value on
  # collision. Jenga rejects repeats with 400101, and refs must never be reused,
  # even after a failed transaction, so generate a fresh one for every attempt.
  def self.generate_reference
    Array.new(REFERENCE_LENGTH) { REFERENCE_ALPHABET.sample(random: SecureRandom) }.join
  end

  # Amount as a 2-decimal string ("5.00"). Use this exact value in BOTH the request
  # body and the signature. Jenga rounds up to a whole number during processing.
  def self.format_amount(amount)
    value = BigDecimal(amount.to_s)
    raise ArgumentError, "amount must be positive" unless value.positive?

    format("%.2f", value)
  end

  # Normalizes Kenyan numbers to 254XXXXXXXXX (no "+", spaces or leading zero).
  def self.normalize_ke_mobile(number)
    digits = number.to_s.gsub(/\D/, "")
    digits = "254#{digits[1..]}" if digits.match?(/\A0\d{9}\z/)
    digits = "254#{digits}"      if digits.match?(/\A[17]\d{8}\z/)

    unless digits.match?(/\A254[17]\d{8}\z/)
      raise ArgumentError, "invalid Kenyan mobile number: #{number.inspect}"
    end

    digits
  end

  # Signature for STK push. Order is fixed by Jenga:
  #   merchant.accountNumber + payment.ref + payment.mobileNumber +
  #   payment.telco + payment.amount + payment.currency
  # No spaces or separators. Signed with the private key, then Base64 encoded.
  # Regenerate for every request. All values must match the request body exactly.
  # NOTE: the docs don't name the digest; SHA-256 (SHA256withRSA) is the standard
  # for Jenga. If you get 403 "Invalid signature" with correct ordering, confirm this.
  def self.stk_push_signature(account_number:, ref:, mobile_number:, telco:, amount:, currency:)
    payload = [account_number, ref, mobile_number, telco, amount, currency].join
    sign(payload)
  end

  # Delegates to JengaSigner (RSA-SHA256 + strict Base64) so there is one signing path.
  def self.sign(payload)
    JengaSigner.new(private_key_pem: Rails.application.config.jenga[:private_key]).sign(payload)
  end

  # Builds the request body and Signature header for an STK push in one place so the
  # signed values and the body values can never drift apart.
  #
  #   built = Jenga.build_stk_push(mobile_number: "0722000000", amount: 5,
  #                                ref: ref, callback_url: url)
  #   post(Jenga.stk_push_url, json: built[:body],
  #        headers: { "Authorization" => "Bearer #{token}", "Signature" => built[:signature] })
  def self.build_stk_push(mobile_number:, amount:, ref:, callback_url:,
                          currency: "KES", country_code: "KE", push_type: "STK",
                          telco: TELCO_SAFARICOM, merchant_name: nil, date: Date.current)
    cfg = Rails.application.config.jenga

    unless ref.to_s.match?(/\A[A-Za-z0-9]{1,#{REFERENCE_LENGTH}}\z/)
      raise ArgumentError, "ref must be 1-#{REFERENCE_LENGTH} alphanumeric characters"
    end

    account_number = cfg[:source_account]
    mobile         = normalize_ke_mobile(mobile_number)
    amount_str     = format_amount(amount)

    body = {
      merchant: {
        countryCode:   country_code,
        accountNumber: account_number,
        name:          merchant_name || cfg[:merchant_code]
      },
      payment: {
        ref:          ref,
        amount:       amount_str,
        currency:     currency,
        telco:        telco,
        mobileNumber: mobile,
        date:         date.strftime("%Y-%m-%d"),
        callBackUrl:  callback_url,
        pushType:     push_type
      }
    }

    signature = stk_push_signature(
      account_number: account_number,
      ref:            ref,
      mobile_number:  mobile,
      telco:          telco,
      amount:         amount_str,
      currency:       currency
    )

    { body: body, signature: signature }
  end
end

Rails.application.config.jenga = {
  environment:     ENV.fetch("JENGA_ENV", "sandbox"),
  api_key:         ENV["JENGA_API_KEY"],
  merchant_code:   ENV["JENGA_MERCHANT_CODE"],
  consumer_secret: ENV["JENGA_CONSUMER_SECRET"],
  private_key:     ENV["JENGA_PRIVATE_KEY"],
  source_account:  ENV["JENGA_SOURCE_ACCOUNT"],
  ipn_username:    ENV["JENGA_IPN_USERNAME"],
  ipn_password:    ENV["JENGA_IPN_PASSWORD"]
}