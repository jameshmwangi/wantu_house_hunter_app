class AppointmentMailer < ApplicationMailer
  def booking_confirmed(appointment)
    @appointment = appointment
    @listing = appointment.listing
    @seeker = appointment.home_seeker
    mail(to: @seeker.email, subject: t('mailers.booking_confirmed.subject', title: @listing.title))
  end

  def booking_declined(appointment)
    @appointment = appointment
    @listing = appointment.listing
    @seeker = appointment.home_seeker
    mail(to: @seeker.email, subject: t('mailers.booking_declined.subject', title: @listing.title))
  end

  def booking_completed(appointment)
    @appointment = appointment
    @listing = appointment.listing
    @seeker = appointment.home_seeker
    @agent = appointment.agent
    mail(to: @seeker.email, subject: t('mailers.booking_completed.subject', title: @listing.title))
  end

  def new_booking(appointment)
    @appointment = appointment
    @listing = appointment.listing
    @agent = appointment.agent
    @seeker = appointment.home_seeker
    mail(to: @agent.email, subject: t('mailers.new_booking.subject', title: @listing.title))
  end
end
