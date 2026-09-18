class LedgerEntry < ApplicationRecord
  belongs_to :escrow_transaction

  ACCOUNTS = %w[home_seeker_suspense escrow_holding agent_payable platform_fee cash_out home_seeker_refundable].freeze
  ENTRY_TYPES = %w[debit credit].freeze

  validates :account, inclusion: { in: ACCOUNTS }
  validates :entry_type, inclusion: { in: ENTRY_TYPES }
  validates :amount_cents, numericality: { only_integer: true, greater_than_or_equal_to: 0 }
  validates :currency, presence: true
end
