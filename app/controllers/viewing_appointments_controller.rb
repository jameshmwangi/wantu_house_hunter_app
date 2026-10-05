class ViewingAppointmentsController < ApplicationController
  before_action :authenticate_user!
  before_action :set_listing
  before_action :prevent_self_booking

  def new
    @appointment = @listing.viewing_appointments.build(
      fee_amount: @listing.viewing_fee
    )
    authorize! :create, @appointment
  end

  def create
    @appointment = @listing.viewing_appointments.build(appointment_params)
    @appointment.home_seeker = current_user
    @appointment.agent = @listing.user
    @appointment.fee_amount = @listing.viewing_fee
    authorize! :create, @appointment

    if @appointment.save
      phone_number = PaymentAttempt.normalize_msisdn(current_user.phone_number.to_s)

      payment = @appointment.initiate_pesapal_payment!(
        phone_number: phone_number,
        callback_url: api_v1_pesapal_callback_url
      )

      if payment.redirect_url.present?
        redirect_to payment.redirect_url, allow_other_host: true, status: :see_other
      elsif payment.outcome == 'success'
        redirect_to listing_path(@listing), notice: t('payment_attempts.success', reference: payment.payment_reference)
      else
        redirect_to listing_path(@listing), notice: t('payment_attempts.stk_initiated', default: 'Booking received. Please check your payment status.')
      end
    else
      render :new, status: :unprocessable_entity
    end
  rescue PaymentGatewayAdapter::Error, PesapalClient::PesapalError => e
    Rails.logger.error "[ViewingAppointmentsController#create] Gateway error: #{e.message}"
    redirect_to listing_path(@listing), alert: t('payment_attempts.gateway_error', default: 'Payment initiation failed — please try again.')
  rescue => e
    Rails.logger.error "[ViewingAppointmentsController#create] Error: #{e.class} — #{e.message}"
    redirect_to listing_path(@listing), alert: t('payment_attempts.failure', default: 'Payment failed. Please try again.')
  end

  private

  def prevent_self_booking
    return unless @listing.user_id == current_user.id

    redirect_to listing_path(@listing), alert: t('errors.cannot_book_own_listing')
  end

  def set_listing
    @listing = Listing.published.find(params[:listing_id])
  end

  def appointment_params
    params.require(:viewing_appointment).permit(:scheduled_at)
  end
end
