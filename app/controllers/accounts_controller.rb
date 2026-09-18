class AccountsController < ApplicationController
  before_action :authenticate_user!

  def show
    @user = current_user
    @appointments = current_user.viewing_appointments
                                .includes(:listing, :agent)
                                .order(scheduled_at: :desc)
                                .limit(5)
  end

  def edit
    @user = current_user
  end

  def update
    @user = current_user

    if password_update_requested?
      update_with_password
    else
      update_profile
    end
  end

  private

  def update_profile
    if @user.update(account_params)
      redirect_to account_path, notice: t('users.updated')
    else
      render :edit, status: :unprocessable_entity
    end
  end

  def update_with_password
    unless @user.valid_password?(params[:user][:current_password])
      @user.errors.add(:current_password, t('errors.messages.invalid'))
      return render :edit, status: :unprocessable_entity
    end

    if @user.update(account_params_with_password)
      bypass_sign_in(@user)
      redirect_to account_path, notice: t('users.updated')
    else
      render :edit, status: :unprocessable_entity
    end
  end

  def password_update_requested?
    params[:user][:password].present?
  end

  def account_params
    params.require(:user).permit(:full_name, :phone_number, :bio, :avatar)
  end

  def account_params_with_password
    params.require(:user).permit(:full_name, :phone_number, :bio, :password, :password_confirmation)
  end
end
