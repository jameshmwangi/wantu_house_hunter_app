class PaymentAttemptsController < ApplicationController
  before_action :authenticate_user!
  before_action :set_appointment

  def new
    authorize! :create, PaymentAttempt
    @listing        = @appointment.listing
    @payment_method = params[:payment_method].presence || 'mpesa'
  end

  # POST /payment_attempts
  # M-Pesa: initiates a real Jenga STK push and immediately returns a Turbo
  # Stream that renders the "processing" spinner. The IPN callback (received by
  # Api::V1::PaymentsController#ipn) pushes the final status via Turbo broadcast.
  #
  # Card / fallback: kept for non-M-Pesa paths (card is still simulated until
  # a live card gateway is wired in).
  def create
    authorize! :create, PaymentAttempt

    if @appointment.fee_status == 'paid'
      return redirect_to listing_path(@appointment.listing),
                          alert: t('payment_attempts.already_paid')
    end

    payment_method = params[:payment_method].presence || 'mpesa'

    if payment_method == 'mpesa'
      phone_number = PaymentAttempt.normalize_msisdn(
        params[:phone_number].presence || current_user.phone_number.to_s
      )

      @payment = @appointment.initiate_stk_payment!(
        phone_number:  phone_number,
        callback_url:  api_v1_jenga_ipn_url
      )

      respond_to do |format|
        format.turbo_stream # renders create.turbo_stream.erb
        format.html { redirect_to listing_path(@appointment.listing), notice: t('payment_attempts.stk_initiated', default: 'Check your phone to complete M-Pesa payment.') }
      end

    else
      # Legacy simulation path for card (and non-production M-Pesa when Jenga
      # credentials are absent — PaymentGatewayAdapter auto-falls back to simulation)
      simulation = params[:payment_simulation].presence || 'success'
      @payment = @appointment.process_payment!(payment_method: payment_method, simulation: simulation)

      if @payment.outcome == 'success'
        redirect_to listing_path(@appointment.listing), notice: t('payment_attempts.success', reference: @payment.payment_reference)
      else
        redirect_to listing_path(@appointment.listing), alert: t('payment_attempts.failure')
      end
    end

  rescue JengaClient::JengaError => e
    Rails.logger.error "[PaymentAttemptsController#create] JengaError: #{e.message}"
    redirect_to listing_path(@appointment.listing),
                alert: t('payment_attempts.gateway_error', default: 'Payment initiation failed — please try again.')
  rescue => e
    Rails.logger.error "[PaymentAttemptsController#create] Error: #{e.class} — #{e.message}"
    redirect_to listing_path(@appointment.listing),
                alert: t('payment_attempts.failure')
  end

  # GET /payment_attempts/:id/status
  # Renders the _status partial — used as a fallback for browsers without
  # WebSocket support (they can poll this endpoint manually).
  def status
    authorize! :read, PaymentAttempt
    @payment = @appointment.payment_attempts.find(params[:id])
    render partial: 'payment_attempts/status', locals: { payment: @payment }
  end

  private

  def set_appointment
    @appointment = current_user.viewing_appointments.find(params[:viewing_appointment_id])
  end
end

