module Dashboard
  class ViewingAppointmentsController < BaseController
    before_action :set_appointment, only: [:update, :release_escrow]

    ALLOWED_ACTIONS = %w[confirm decline].freeze

    def index
      @appointments = current_user.agent_appointments
                                  .includes(:listing, :home_seeker, payment_attempts: [])
                                  .order(created_at: :desc)
      @appointments = @appointments.where(status: params[:status]) if params[:status].present?
      @appointments = @appointments.page(params[:page]).per(10)

      raw_counts = current_user.agent_appointments.group(:status).count
      @counts = {
        all:       raw_counts.values.sum,
        pending:   raw_counts['pending'].to_i,
        confirmed: raw_counts['confirmed'].to_i,
        completed: raw_counts['completed'].to_i
      }
    end

    def update
      unless ALLOWED_ACTIONS.include?(params[:status_action])
        return redirect_to dashboard_appointments_path, alert: t('errors.not_authorized')
      end

      authorize! params[:status_action].to_sym, @appointment
      @appointment.transition_to!(params[:status_action])
      redirect_to dashboard_appointments_path, notice: t("dashboard.booking_#{ViewingAppointment::TRANSITION_STATUSES[params[:status_action]]}")
    end

    def release_escrow
      authorize! :complete, @appointment
      @appointment.escrow_transaction.release!(code: params.require(:confirmation_code))
      redirect_to dashboard_appointments_path, notice: "Visit confirmed and escrow released."
    rescue EscrowTransaction::InvalidTransition, EscrowTransaction::InvalidConfirmationCode => error
      redirect_to dashboard_appointments_path, alert: error.message
    end

    private

    def set_appointment
      @appointment = current_user.agent_appointments.find(params[:id])
    end
  end
end
