class PaymentTransaction < ApplicationRecord
  belongs_to :escrow_transaction

  DIRECTIONS = %w[collection payout].freeze
  STATUSES = %w[initiated pending success failed].freeze

  validates :direction, inclusion: { in: DIRECTIONS }
  validates :status, inclusion: { in: STATUSES }
  validates :amount_cents, numericality: { only_integer: true, greater_than_or_equal_to: 0 }
  validates :provider_reference, uniqueness: true, allow_nil: true
end
