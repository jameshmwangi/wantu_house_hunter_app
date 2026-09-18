class PayoutAccount < ApplicationRecord
  belongs_to :agent, class_name: "User"
  has_many :withdrawals, dependent: :restrict_with_exception

  COUNTRIES = %w[KE UG].freeze
  KINDS = %w[mpesa momo airtel_money bank].freeze

  encrypts :details

  validates :country, inclusion: { in: COUNTRIES }
  validates :kind, inclusion: { in: KINDS }
  validates :details, presence: true
  validates :kind, uniqueness: { scope: %i[agent_id country] }
end
