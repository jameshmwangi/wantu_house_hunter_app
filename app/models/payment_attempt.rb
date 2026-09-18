class PaymentAttempt < ApplicationRecord
  belongs_to :viewing_appointment

  PAYMENT_METHODS = %w[mpesa card].freeze
  OUTCOMES        = %w[success failed pending].freeze
  STK_STATUSES    = %w[pending processing completed failed timed_out].freeze

  validates :payment_method, presence: true, inclusion: { in: PAYMENT_METHODS }
  validates :outcome,     presence: true, inclusion: { in: OUTCOMES }
  validates :stk_status, presence: true, inclusion: { in: STK_STATUSES }

  scope :successful,      -> { where(outcome: 'success') }
  scope :failed,          -> { where(outcome: 'failed') }
  scope :pending_outcome, -> { where(outcome: 'pending') }

  # STK-specific scopes
  scope :stk_processing, -> { where(stk_status: 'processing') }
  scope :stk_completed,  -> { where(stk_status: 'completed') }
  scope :stk_stale,      -> { stk_processing.where('created_at < ?', 90.seconds.ago) }

  # Normalise an MSISDN entered as 07xx... or +2547xx... -> 2547xxxxxxxx
  def self.normalize_msisdn(number)
    number.to_s.strip.gsub(/\A\+/, '').gsub(/\A0/, '254').gsub(/\s+/, '')
  end
end
