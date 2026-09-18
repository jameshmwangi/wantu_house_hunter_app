class ViewingAppointment < ApplicationRecord
  belongs_to :listing
  belongs_to :home_seeker, class_name: "User", foreign_key: :home_seeker_id
  belongs_to :agent,       class_name: "User", foreign_key: :agent_id

  has_many :payment_attempts, dependent: :destroy
  has_one :escrow_transaction, dependent: :restrict_with_exception

  STATUSES     = %w[pending awaiting_confirmation confirmed declined completed].freeze
  FEE_STATUSES = %w[unpaid paid].freeze

  validates :scheduled_at, presence: true
  validates :fee_amount, numericality: { greater_than_or_equal_to: 0 }
  validates :status, presence: true, inclusion: { in: STATUSES }
  validates :fee_status, presence: true, inclusion: { in: FEE_STATUSES }

  scope :status_completed, -> { where(status: 'completed') }

  TRANSITION_MAILERS = {
    'confirm'  => :booking_confirmed,
    'decline'  => :booking_declined,
    'complete' => :booking_completed
  }.freeze

  TRANSITION_STATUSES = {
    'confirm'  => 'confirmed',
    'decline'  => 'declined',
    'complete' => 'completed'
  }.freeze

  def transition_to!(action)
    new_status = TRANSITION_STATUSES.fetch(action)
    update!(status: new_status)
    mailer_method = TRANSITION_MAILERS.fetch(action)
    AppointmentMailer.public_send(mailer_method, self).deliver_later
  end

  def process_payment!(payment_method:, simulation:)
    # Zero-amount (free) viewings skip the gateway entirely — design doc §1.4
    if fee_amount.to_i == 0
      escrow_transaction_or_create!.fund!
      AppointmentMailer.new_booking(self).deliver_later
      return OpenStruct.new(outcome: 'success', payment_reference: nil, payment_method: nil)
    end

    outcome = simulation == 'success' ? 'success' : 'failed'

    payment = payment_attempts.create!(
      payment_method: payment_method,
      outcome: outcome,
      payment_reference: outcome == 'success' ? "WTU-#{SecureRandom.hex(6).upcase}" : nil
    )

    if outcome == 'success'
      escrow_transaction_or_create!.fund!(provider_reference: payment.payment_reference, payload: { "payment_type" => payment_method })
      AppointmentMailer.new_booking(self).deliver_later
      PaymentMailer.payment_success(payment).deliver_later
    else
      PaymentMailer.payment_failed(payment).deliver_later
    end

    payment
  end

  def escrow_transaction_or_create!
    return escrow_transaction if escrow_transaction

    country = listing.location.country.to_s.downcase.match?(/uganda|\Aug\z/) ? "UG" : "KE"
    create_escrow_transaction!(listing: listing, home_seeker: home_seeker, agent: agent,
                               amount_cents: fee_amount.to_i * 100,
                               currency: country == "UG" ? "UGX" : "KES", country: country)
  end
end
