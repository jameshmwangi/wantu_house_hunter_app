module Dashboard
  class WithdrawalsController < BaseController
    def index
      @withdrawals = current_user.withdrawals.includes(:payout_account).order(created_at: :desc)
      @payout_accounts = current_user.payout_accounts.where(verified: true).or(
        current_user.payout_accounts.all
      ).order(:country, :kind)
      @available_kes = current_user.available_payable_cents("KES")
      @available_ugx = current_user.available_payable_cents("UGX")
      @new_withdrawal = Withdrawal.new
    end

    def create
      payout_account = current_user.payout_accounts.find(params[:withdrawal][:payout_account_id])
      currency = payout_account.country == "UG" ? "UGX" : "KES"
      amount_cents = (params[:withdrawal][:amount].to_f * 100).to_i

      @new_withdrawal = current_user.withdrawals.build(
        payout_account: payout_account,
        amount_cents: amount_cents,
        currency: currency,
        status: "requested",
        requested_at: Time.current
      )

      authorize! :create, @new_withdrawal

      if amount_cents <= 0
        @new_withdrawal.errors.add(:amount, t('withdrawals.errors.amount_positive'))
        return render_index_with_errors
      end

      if amount_cents > current_user.available_payable_cents(currency)
        @new_withdrawal.errors.add(:amount, t('withdrawals.errors.insufficient_balance'))
        return render_index_with_errors
      end

      if @new_withdrawal.save
        @new_withdrawal.initiate!(simulate_success: true)
        redirect_to dashboard_withdrawals_path, notice: t('withdrawals.created')
      else
        render_index_with_errors
      end
    rescue ActiveRecord::RecordInvalid => error
      @new_withdrawal.errors.add(:base, error.message)
      render_index_with_errors
    end

    private

    def render_index_with_errors
      @withdrawals = current_user.withdrawals.includes(:payout_account).order(created_at: :desc)
      @payout_accounts = current_user.payout_accounts.order(:country, :kind)
      @available_kes = current_user.available_payable_cents("KES")
      @available_ugx = current_user.available_payable_cents("UGX")
      render :index, status: :unprocessable_entity
    end
  end
end
