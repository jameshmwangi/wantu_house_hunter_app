module Dashboard
  class PayoutAccountsController < BaseController
    before_action :set_payout_account, only: [:destroy]

    def index
      @payout_accounts = current_user.payout_accounts.order(:country, :kind)
      @new_payout_account = PayoutAccount.new
    end

    def create
      @new_payout_account = current_user.payout_accounts.build(payout_account_params)
      authorize! :create, @new_payout_account

      if @new_payout_account.save
        redirect_to dashboard_payout_accounts_path,
                    notice: t('payout_accounts.created')
      else
        @payout_accounts = current_user.payout_accounts.order(:country, :kind)
        render :index, status: :unprocessable_entity
      end
    end

    def destroy
      authorize! :destroy, @payout_account
      if @payout_account.withdrawals.exists?
        redirect_to dashboard_payout_accounts_path,
                    alert: t('payout_accounts.cannot_delete_with_withdrawals')
      else
        @payout_account.destroy!
        redirect_to dashboard_payout_accounts_path,
                    notice: t('payout_accounts.destroyed')
      end
    end

    private

    def set_payout_account
      @payout_account = current_user.payout_accounts.find(params[:id])
    end

    def payout_account_params
      params.require(:payout_account).permit(:country, :kind, :details)
    end
  end
end
