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
      redirect_to new_payment_attempt_path(
        viewing_appointment_id: @appointment.id,
        payment_method: params[:payment_method].presence || 'mpesa'
      )
    else
      render :new, status: :unprocessable_entity
    end
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
