# frozen_string_literal: true

class Users::OmniauthCallbacksController < Devise::OmniauthCallbacksController
  # Called by Devise after Google redirects back to /users/auth/google_oauth2/callback
  def google_oauth2
    @user = User.find_for_google(request.env["omniauth.auth"])

    if @user.persisted?
      sign_in_and_redirect @user, event: :authentication
      set_flash_message(:notice, :success, kind: "Google") if is_navigational_format?
    else
      # Store partial data so the registration form can be pre-filled
      session["devise.google_data"] = request.env["omniauth.auth"].except("extra")
      redirect_to new_user_registration_url, alert: @user.errors.full_messages.join("\n")
    end
  end

  # Handles user clicking "cancel" on the Google consent screen
  def failure
    redirect_to root_path, alert: "Google sign-in was cancelled or failed. Please try again."
  end
end
