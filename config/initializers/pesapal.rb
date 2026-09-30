# frozen_string_literal: true

# Pesapal API 3.0 configuration.
#
# Required environment variables:
#   PESAPAL_ENV             — "sandbox" or "production"
#   PESAPAL_CONSUMER_KEY    — from Pesapal merchant dashboard
#   PESAPAL_CONSUMER_SECRET — from Pesapal merchant dashboard
#   PESAPAL_IPN_ID          — GUID returned from RegisterIPN (run once, store the result)
#
# Sandbox base URL : https://cybqa.pesapal.com/pesapalv3/
# Production base URL: https://pay.pesapal.com/v3/
#
# Sandbox test credentials: https://developer.pesapal.com/api3-demo-keys.txt
#
# IPN registration (one-time per domain, run from Rails console):
#   client = PesapalClient.new
#   ipn_id = client.register_ipn(ipn_url: "https://<your-domain>/api/v1/pesapal/ipn")
#   puts ipn_id   # → store this in PESAPAL_IPN_ID
#
# For local development, expose your IPN URL via ngrok:
#   ngrok http 3000
#   # Use the https ngrok URL as your IPN URL above

module Pesapal
  BASE_URLS = {
    "sandbox"    => "https://cybqa.pesapal.com/pesapalv3",
    "production" => "https://pay.pesapal.com/v3"
  }.freeze

  def self.base_url
    BASE_URLS.fetch(Rails.application.config.pesapal[:environment])
  end

  # Returns true when the Pesapal integration is fully configured with real credentials.
  # Falls back to simulation mode when credentials are absent (development/test).
  def self.configured?
    key    = Rails.application.config.pesapal[:consumer_key]
    secret = Rails.application.config.pesapal[:consumer_secret]

    key.present? &&
      !key.start_with?("your_") &&
      secret.present? &&
      !secret.start_with?("your_")
  end
end

Rails.application.config.pesapal = {
  environment:     ENV.fetch("PESAPAL_ENV", "sandbox"),
  consumer_key:    ENV["PESAPAL_CONSUMER_KEY"],
  consumer_secret: ENV["PESAPAL_CONSUMER_SECRET"],
  ipn_id:          ENV["PESAPAL_IPN_ID"]
}
