module Dashboard
  class BaseController < ApplicationController
    before_action :authenticate_user!
    before_action :require_dashboard_access!

    private

    # Allows property managers (agents, landlords) and home seekers.
    # Home seekers need access to create their first listing (triggers auto-upgrade).
    def require_dashboard_access!
      return if current_user.property_manager? || current_user.home_seeker?

      redirect_to root_path, alert: t('errors.not_authorized')
    end
  end
end
