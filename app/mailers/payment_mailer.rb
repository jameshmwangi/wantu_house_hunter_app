class PaymentMailer < ApplicationMailer
  def payment_success(payment_attempt)
    @attempt     = payment_attempt
    @appointment = payment_attempt.viewing_appointment
    @listing     = @appointment.listing
    @seeker      = @appointment.home_seeker
    mail(to: @seeker.email, subject: t('mailers.payment_success.subject', title: @listing.title))
  end

  def payment_failed(payment_attempt)
    @attempt     = payment_attempt
    @appointment = payment_attempt.viewing_appointment
    @listing     = @appointment.listing
    @seeker      = @appointment.home_seeker
    mail(to: @seeker.email, subject: t('mailers.payment_failed.subject', title: @listing.title))
  end
end
