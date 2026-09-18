class GuestSessionsController < ApplicationController
  GUEST_ACCOUNTS = {
    'admin' => 'admin@wantu.africa',
    'agent' => 'abdalla@wantu.africa',
    'home_seeker' => 'brian@wantu.africa'
  }.freeze

  def create
    role  = params[:role].to_s
    email = GUEST_ACCOUNTS.fetch(role, GUEST_ACCOUNTS['home_seeker'])
    user  = User.find_by(email: email)

    if user
      sign_in(user)
      flash[:notice] = t('guest_login.signed_in_as', role: t("roles.#{user.role}"))
      redirect_to(user.admin? ? rails_admin.dashboard_path : root_path)
    else
      flash[:alert] = t('guest_login.unavailable')
      redirect_to new_user_session_path
    end
  end
end
