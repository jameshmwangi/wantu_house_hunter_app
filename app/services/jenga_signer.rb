# frozen_string_literal: true

require "openssl"
require "base64"

# Signs Jenga API requests using RSA-SHA256.
#
# Jenga requires a `Signature` header on all money-moving endpoints (collection
# and payout). The signature is produced by:
#   1. Concatenating specific request fields in a defined order (no separators).
#   2. Signing the concatenated string with your RSA private key using SHA-256.
#   3. Base64-encoding the raw signature bytes (strict, no line breaks).
#
# IMPORTANT — field order is endpoint-specific. Getting it wrong yields a 403
# "Invalid signature" with no further detail. Always verify against Jenga docs
# per endpoint. Do NOT assume all endpoints share the same field order.
#
# Usage:
#   signer = JengaSigner.new
#   sig = signer.sign(order_reference, currency, phone, amount_str)
class JengaSigner
  # @param private_key_pem [String] PEM contents of the RSA private key.
  #   Defaults to JENGA_PRIVATE_KEY env var. The value may use literal '\n'
  #   (as stored in Render env vars) — these are normalised to real newlines.
  def initialize(private_key_pem: ENV.fetch("JENGA_PRIVATE_KEY", nil))
    raise ArgumentError, "JENGA_PRIVATE_KEY is not set" if private_key_pem.blank?

    pem = private_key_pem.gsub('\n', "\n")
    @private_key = OpenSSL::PKey::RSA.new(pem)
  end

  # Concatenate +fields+ (no separator) and return a Base64-encoded RSA-SHA256 signature.
  #
  # @param fields [Array<String>] fields in the order mandated by Jenga for this endpoint.
  # @return [String] Base64-strict-encoded signature, safe for use as an HTTP header value.
  def sign(*fields)
    data      = fields.join   # NOTE: no separators — Jenga specifies raw concatenation
    signature = @private_key.sign(OpenSSL::Digest.new("SHA256"), data)
    Base64.strict_encode64(signature)
  end
end
