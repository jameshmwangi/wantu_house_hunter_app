class EscrowTransaction < ApplicationRecord
  belongs_to :viewing_appointment
  belongs_to :listing
  belongs_to :home_seeker, class_name: "User"
  belongs_to :agent, class_name: "User"
  has_many :ledger_entries, dependent: :restrict_with_exception
  has_many :payment_transactions, dependent: :restrict_with_exception

  STATUSES = %w[pending funded released refunded cancelled disputed].freeze
  CODE_LIFETIME = 30.days
  MAX_CONFIRMATION_ATTEMPTS = 5

  validates :status, inclusion: { in: STATUSES }
  validates :amount_cents, numericality: { only_integer: true, greater_than_or_equal_to: 0 }
  validates :currency, presence: true
  validates :country, inclusion: { in: %w[KE UG] }

  def fund!(provider_reference: nil, payload: {})
    with_lock do
      return self if funded? || released?
      raise InvalidTransition, "only pending escrow can be funded" unless pending?

      transaction do
        post_pair!("home_seeker_suspense", "escrow_holding") if amount_cents > 0
        # For zero-amount escrow, skip the gateway call entirely (see design §1.4)
        record_successful_collection!(provider_reference, payload) if provider_reference.present? && amount_cents > 0
        update!(status: "funded", funded_at: Time.current,
                confirmation_code: amount_cents > 0 ? confirmation_code_value : nil,
                confirmation_code_expires_at: amount_cents > 0 ? CODE_LIFETIME.from_now : nil)
        viewing_appointment.update!(fee_status: "paid")
      end
    end
  end

  def release!(code:)
    with_lock do
      raise InvalidTransition, "escrow is not funded" unless funded?
      raise InvalidTransition, "confirmation code has expired" if confirmation_code_expires_at < Time.current
      raise InvalidTransition, "confirmation attempts exceeded" if confirmation_attempts >= MAX_CONFIRMATION_ATTEMPTS

      unless ActiveSupport::SecurityUtils.secure_compare(confirmation_code.to_s, code.to_s)
        increment!(:confirmation_attempts)
        raise InvalidConfirmationCode, "confirmation code is invalid"
      end

      transaction do
        post_pair!("escrow_holding", "agent_payable")
        update!(status: "released", released_at: Time.current)
        viewing_appointment.update!(status: "completed")
      end
    end
  end

  def pending?  = status == "pending"
  def funded?   = status == "funded"
  def released? = status == "released"
  def disputed? = status == "disputed"
  def refunded? = status == "refunded"

  # Reverse Step 1: refund held funds back to the home seeker.
  # Writes debit escrow_holding / credit home_seeker_refundable.
  # A separate payout flow then disburses to the home seeker (same
  # pattern as an agent withdrawal — not automated here).
  def refund!
    with_lock do
      raise InvalidTransition, "only funded escrow can be refunded" unless funded?

      transaction do
        post_pair!("escrow_holding", "home_seeker_refundable") if amount_cents > 0
        update!(status: "refunded")
        viewing_appointment.update!(status: "declined")
      end
    end
  end

  class InvalidTransition < StandardError; end
  class InvalidConfirmationCode < StandardError; end

  private

  def post_pair!(debit_account, credit_account)
    ledger_entries.create!([
      { account: debit_account, entry_type: "debit", amount_cents: amount_cents, currency: currency },
      { account: credit_account, entry_type: "credit", amount_cents: amount_cents, currency: currency }
    ])
  end

  def record_successful_collection!(reference, payload)
    payment_transactions.find_or_create_by!(provider_reference: reference) do |payment|
      payment.direction = "collection"
      payment.provider_channel = payload["payment_type"]
      payment.status = "success"
      payment.amount_cents = amount_cents
      payment.raw_payload = payload
    end
  end

  def confirmation_code_value
    format("%06d", SecureRandom.random_number(1_000_000))
  end
end
