class ApplicationController < ActionController::Base
  before_action :configure_permitted_parameters, if: :devise_controller?

  rescue_from CanCan::AccessDenied do |_exception|
    redirect_to root_path, alert: t('errors.not_authorized')
  end

  rescue_from ActiveRecord::RecordNotFound do |_exception|
    render 'errors/not_found', status: :not_found
  end

  # After sign-in: honour redirect_to param, then Devise stored location, then dashboard/root
  def after_sign_in_path_for(resource)
    redirect_target = stored_location_for(resource)
    if params[:redirect_to].present?
      safe = URI.parse(params[:redirect_to]).path rescue nil
      safe || redirect_target || root_path
    else
      redirect_target || root_path
    end
  end

  # After sign-out: always redirect to home
  def after_sign_out_path_for(_resource_or_scope)
    root_path
  end

  private

  def require_admin!
    return if current_user&.admin?

    redirect_to root_path, alert: t('errors.not_authorized')
  end

  def configure_permitted_parameters
    devise_parameter_sanitizer.permit(:sign_up, keys: [:full_name, :phone_number, :role])
    devise_parameter_sanitizer.permit(:account_update, keys: [:full_name, :phone_number])
  end
end
