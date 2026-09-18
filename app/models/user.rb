class User < ApplicationRecord
  devise :database_authenticatable, :registerable,
         :recoverable, :rememberable, :validatable

  ROLES = %w[home_seeker agent landlord admin].freeze

  has_many :listings,             dependent: :destroy
  has_many :favourites,           dependent: :destroy
  has_many :favourite_listings,   through: :favourites, source: :listing

  # As home seeker
  has_many :viewing_appointments, foreign_key: :home_seeker_id, dependent: :destroy

  # As agent
  has_many :agent_appointments,   class_name: "ViewingAppointment",
                                  foreign_key: :agent_id, dependent: :nullify

  # Reviews written about this user (as agent)
  has_many :agent_reviews,        foreign_key: :agent_id, dependent: :destroy

  # Reviews this user authored
  has_many :authored_reviews,     class_name: "AgentReview",
                                  foreign_key: :author_id, dependent: :destroy

  has_many :property_comments,    foreign_key: :author_id, dependent: :destroy
  has_many :agent_escrow_transactions, class_name: "EscrowTransaction", foreign_key: :agent_id, dependent: :restrict_with_exception
  has_many :payout_accounts, foreign_key: :agent_id, dependent: :restrict_with_exception
  has_many :withdrawals, foreign_key: :agent_id, dependent: :restrict_with_exception

  has_one_attached :avatar

  validates :full_name, presence: true
  validates :role, presence: true, inclusion: { in: ROLES }
  validate :acceptable_avatar
  validate :password_complexity

  def avatar_role_class
    "avatar-role--#{role}"
  end

  def property_manager?
    agent? || landlord?
  end

  def admin?
    role == 'admin'
  end

  def agent?
    role == 'agent'
  end

  def landlord?
    role == 'landlord'
  end

  def home_seeker?
    role == 'home_seeker'
  end

  def upgrade_to_agent!
    update!(role: 'agent') if home_seeker?
  end

  def active_listings_count
    listings.published.count
  end

  def booking_requests_count
    agent_appointments.count
  end

  def fees_this_month
    agent_appointments
      .where(fee_status: 'paid')
      .where('viewing_appointments.created_at >= ?', Time.current.beginning_of_month)
      .sum(:fee_amount)
  end

  def average_agent_rating
    agent_reviews.average(:rating)&.round(1) || 0.0
  end

  def available_payable_cents(currency)
    scope = LedgerEntry.joins(:escrow_transaction)
                       .where(escrow_transactions: { agent_id: id }, account: "agent_payable", currency: currency)
    scope.where(entry_type: "credit").sum(:amount_cents) - scope.where(entry_type: "debit").sum(:amount_cents)
  end

  private

  def acceptable_avatar
    return unless avatar.attached?

    unless avatar.blob.content_type.in?(%w[image/png image/jpeg image/webp])
      errors.add(:avatar, 'must be a PNG, JPEG, or WebP image')
    end

    if avatar.blob.byte_size > 5.megabytes
      errors.add(:avatar, 'must be less than 5 MB')
    end
  end

  def password_complexity
    return if password.blank?

    unless password.length >= 8
      errors.add(:password, 'must be at least 8 characters long')
    end

    unless password.match?(/[A-Z]/)
      errors.add(:password, 'must include at least one uppercase letter')
    end

    unless password.match?(/[a-z]/)
      errors.add(:password, 'must include at least one lowercase letter')
    end

    unless password.match?(/[0-9]/)
      errors.add(:password, 'must include at least one number')
    end
  end
end
