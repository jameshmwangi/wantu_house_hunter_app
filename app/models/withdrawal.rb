class Withdrawal < ApplicationRecord
  belongs_to :agent, class_name: "User"
  belongs_to :payout_account
  belongs_to :payment_transaction, optional: true

  STATUSES = %w[requested processing paid failed].freeze

  validates :status, inclusion: { in: STATUSES }
  validates :amount_cents, numericality: { only_integer: true, greater_than: 0 }
  validates :currency, presence: true
  validate :payout_account_belongs_to_agent

  def requested?   = status == "requested"
  def processing?  = status == "processing"
  def paid?        = status == "paid"
  def failed?      = status == "failed"

  # Step 1: kick off the payout. In simulation mode (no real provider),
  # this creates the PaymentTransaction record and immediately marks paid.
  # When a real provider is wired, this will set status=processing and wait
  # for the provider webhook to call mark_paid! or mark_failed!.
  def initiate!(simulate_success: true)
    with_lock do
      raise ActiveRecord::RecordInvalid, self unless requested?

      pt = PaymentTransaction.create!(
        # payout PaymentTransactions are not tied to a single escrow_transaction,
        # so we use the first released escrow for this agent as a placeholder anchor.
        # A future refactor can decouple this once a real provider is in place.
        escrow_transaction: agent.agent_escrow_transactions.where(currency: currency, status: "released").order(:released_at).first,
        direction: "payout",
        provider: "simulation",
        provider_channel: payout_account.kind,
        status: simulate_success ? "success" : "failed",
        amount_cents: amount_cents,
        raw_payload: { simulated: true }
      )

      update!(status: "processing", payment_transaction: pt)

      if simulate_success
        mark_paid!
      else
        mark_failed!
      end
    end
  end

  def mark_paid!
    agent.with_lock do
      raise ActiveRecord::RecordInvalid, self if amount_cents > agent.available_payable_cents(currency)

      remaining = amount_cents
      EscrowTransaction.where(agent: agent, currency: currency, status: "released").order(:released_at).find_each do |escrow|
        available = escrow.ledger_entries.where(account: "agent_payable", entry_type: "credit").sum(:amount_cents) -
                    escrow.ledger_entries.where(account: "agent_payable", entry_type: "debit").sum(:amount_cents)
        next if available <= 0

        allocation = [remaining, available].min
        escrow.ledger_entries.create!([
          { account: "agent_payable", entry_type: "debit", amount_cents: allocation, currency: currency },
          { account: "cash_out", entry_type: "credit", amount_cents: allocation, currency: currency }
        ])
        remaining -= allocation
        break if remaining.zero?
      end
      update!(status: "paid", completed_at: Time.current)
    end
  end

  def mark_failed!
    # No ledger entries written — payable balance is untouched so the agent
    # can simply retry the withdrawal. (Design doc §1.3 Step 3)
    update!(status: "failed", completed_at: Time.current)
  end

  private

  def payout_account_belongs_to_agent
    return unless payout_account && agent
    errors.add(:payout_account, "must belong to the agent") unless payout_account.agent_id == agent_id
  end
end
