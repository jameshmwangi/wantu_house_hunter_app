# frozen_string_literal: true

# ──────────────────────────────────────────────────────────────
# OmniAuth — global settings (provider-specific config lives
# in config/initializers/devise.rb via `config.omniauth`)
# ──────────────────────────────────────────────────────────────

# Silence the GET-deprecation warning from omniauth-rails_csrf_protection.
# Devise routes POST to /users/auth/:provider, which is the safe path.
OmniAuth.config.allowed_request_methods = [:post]
