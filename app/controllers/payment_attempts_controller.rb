class PaymentAttemptsController < ApplicationController
  before_action :authenticate_user!
  before_action :set_appointment

  def new
    authorize! :create, PaymentAttempt
    @listing = @appointment.listing
    @payment_method = params[:payment_method].presence || 'mpesa'
  end

  def create
    authorize! :create, PaymentAttempt

    if @appointment.fee_status == 'paid'
      return redirect_to listing_path(@appointment.listing),
                          alert: t('payment_attempts.already_paid')
    end

    payment_method = params[:payment_method].presence || 'mpesa'
    simulation     = params[:payment_simulation].presence || 'success'

    @payment = @appointment.process_payment!(payment_method: payment_method, simulation: simulation)

    if @payment.outcome == 'success'
      redirect_to listing_path(@appointment.listing), notice: t('payment_attempts.success', reference: @payment.payment_reference)
    else
      redirect_to listing_path(@appointment.listing), alert: t('payment_attempts.failure')
    end
  end

  private

  def set_appointment
    @appointment = current_user.viewing_appointments.find(params[:viewing_appointment_id])
  end
end
