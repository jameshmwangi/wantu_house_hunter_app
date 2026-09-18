class PaymentAttempt < ApplicationRecord
  belongs_to :viewing_appointment

  PAYMENT_METHODS = %w[mpesa card].freeze
  OUTCOMES        = %w[success failed pending].freeze

  validates :payment_method, presence: true, inclusion: { in: PAYMENT_METHODS }
  validates :outcome, presence: true, inclusion: { in: OUTCOMES }

  scope :successful,      -> { where(outcome: 'success') }
  scope :failed,          -> { where(outcome: 'failed') }
  scope :pending_outcome, -> { where(outcome: 'pending') }
end
