# frozen_string_literal: true

# Jenga API (Equity Bank / Finserve Africa) configuration.
# Covers Kenya (M-Pesa STK Push) and Uganda (MTN MoMo / Airtel Money) under one integration.
#
# Required environment variables:
#   JENGA_ENV             — "sandbox" or "production"
#   JENGA_API_KEY         — from JengaHQ dashboard
#   JENGA_MERCHANT_CODE   — from JengaHQ dashboard
#   JENGA_CONSUMER_SECRET — from JengaHQ dashboard
#   JENGA_PRIVATE_KEY     — contents of private_key.pem (RSA 2048, PKCS#8), never commit this
#   JENGA_SOURCE_ACCOUNT  — Jenga-linked disbursement account number (for payouts)
#
# Key generation (one-time per environment, sandbox and production must use separate pairs):
#   openssl genpkey -algorithm RSA -out private_key.pem -pkeyopt rsa_keygen_bits:2048
#   openssl rsa -pubout -in private_key.pem -out public_key.pem
#   # Upload public_key.pem to JengaHQ -> Keys
#   # Store private_key.pem contents in JENGA_PRIVATE_KEY env var
#
# IPN registration (dashboard action — not an API call):
#   JengaHQ -> Settings -> IPNs:
#     https://<domain>/api/v1/payments/ipn   (collection callback)
#     https://<domain>/api/v1/payouts/ipn    (payout callback)
#   Register sandbox and production URLs separately.

module Jenga
  BASE_URLS = {
    "sandbox"    => "https://uat.finserve.africa",
    "production" => "https://api.finserve.africa"
  }.freeze

  def self.base_url
    BASE_URLS.fetch(Rails.application.config.jenga[:environment])
  end

  # Returns true when the Jenga integration is fully configured.
  # Falls back to simulation mode when credentials are absent (development/test).
  def self.configured?
    Rails.application.config.jenga[:api_key].present? &&
      Rails.application.config.jenga[:private_key].present?
  end
end

Rails.application.config.jenga = {
  environment:     ENV.fetch("JENGA_ENV", "sandbox"),
  api_key:         ENV["JENGA_API_KEY"],
  merchant_code:   ENV["JENGA_MERCHANT_CODE"],
  consumer_secret: ENV["JENGA_CONSUMER_SECRET"],
  private_key:     ENV["JENGA_PRIVATE_KEY"],
  source_account:  ENV["JENGA_SOURCE_ACCOUNT"]
}
