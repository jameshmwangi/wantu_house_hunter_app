class PaymentAttemptsController < ApplicationController
  before_action :authenticate_user!
  before_action :set_appointment

  def new
    authorize! :create, PaymentAttempt

    if @appointment.fee_status == 'paid'
      return redirect_to listing_path(@appointment.listing),
                          alert: t('payment_attempts.already_paid', default: 'This viewing appointment fee has already been paid.')
    end

    phone_number = PaymentAttempt.normalize_msisdn(current_user.phone_number.to_s)
    @payment = @appointment.initiate_pesapal_payment!(
      phone_number: phone_number,
      callback_url: api_v1_pesapal_callback_url
    )

    if @payment.redirect_url.present?
      redirect_to @payment.redirect_url, allow_other_host: true, status: :see_other
    elsif @payment.outcome == 'success'
      redirect_to listing_path(@appointment.listing), notice: t('payment_attempts.success', reference: @payment.payment_reference)
    else
      redirect_to listing_path(@appointment.listing), notice: t('payment_attempts.stk_initiated', default: 'Complete your payment on the Pesapal page.')
    end
  rescue PaymentGatewayAdapter::Error, PesapalClient::PesapalError => e
    Rails.logger.error "[PaymentAttemptsController#new] PesapalError: #{e.message}"
    redirect_to listing_path(@appointment.listing),
                alert: t('payment_attempts.gateway_error', default: 'Payment initiation failed — please try again.')
  rescue => e
    Rails.logger.error "[PaymentAttemptsController#new] Error: #{e.class} — #{e.message}"
    Rails.logger.error e.backtrace.first(10).join("\n")
    redirect_to listing_path(@appointment.listing),
                alert: t('payment_attempts.failure')
  end

  # POST /payment_attempts
  def create
    authorize! :create, PaymentAttempt

    if @appointment.fee_status == 'paid'
      return redirect_to listing_path(@appointment.listing),
                          alert: t('payment_attempts.already_paid', default: 'This viewing appointment fee has already been paid.')
    end

    if params[:payment_simulation].present?
      simulation = params[:payment_simulation]
      @payment = @appointment.process_payment!(payment_method: 'mpesa', simulation: simulation)

      if @payment.outcome == 'success'
        redirect_to listing_path(@appointment.listing), notice: t('payment_attempts.success', reference: @payment.payment_reference)
      else
        redirect_to listing_path(@appointment.listing), alert: t('payment_attempts.failure')
      end
      return
    end

    phone_number = PaymentAttempt.normalize_msisdn(
      params[:phone_number].presence || current_user.phone_number.to_s
    )

    @payment = @appointment.initiate_pesapal_payment!(
      phone_number:  phone_number,
      callback_url:  api_v1_pesapal_callback_url
    )

    respond_to do |format|
      format.turbo_stream # renders create.turbo_stream.erb
      format.html do
        if @payment.redirect_url.present?
          redirect_to @payment.redirect_url, allow_other_host: true, status: :see_other
        elsif @payment.outcome == 'success'
          redirect_to listing_path(@appointment.listing), notice: t('payment_attempts.success', reference: @payment.payment_reference)
        else
          redirect_to listing_path(@appointment.listing), notice: t('payment_attempts.stk_initiated', default: 'Complete your payment on the Pesapal page.')
        end
      end
    end

  rescue PaymentGatewayAdapter::Error, PesapalClient::PesapalError => e
    Rails.logger.error "[PaymentAttemptsController#create] PesapalError: #{e.message}"
    redirect_to listing_path(@appointment.listing),
                alert: t('payment_attempts.gateway_error', default: 'Payment initiation failed — please try again.')
  rescue => e
    Rails.logger.error "[PaymentAttemptsController#create] Error: #{e.class} — #{e.message}"
    Rails.logger.error e.backtrace.first(10).join("\n")
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

