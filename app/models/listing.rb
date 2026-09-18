class Listing < ApplicationRecord
  belongs_to :user
  belongs_to :location

  has_many :favourites,            dependent: :destroy
  has_many :property_images,       -> { order(created_at: :asc) }, dependent: :destroy
  has_many :viewing_appointments,  dependent: :destroy
  has_many :property_comments,     dependent: :destroy

  NEED_TYPES    = %w[rent buy bnb].freeze
  USE_CASES     = %w[house office event_venue].freeze
  ROOM_LAYOUTS  = %w[single_room bedsitter studio one_bedroom
                     two_bedroom three_bedroom shared].freeze
  PRICE_PERIODS = %w[month week night day total].freeze
  STATUSES      = %w[draft published hidden].freeze

  validates :title,        presence: true
  validates :description,  presence: true
  validates :need_type,    presence: true, inclusion: { in: NEED_TYPES }
  validates :use_case,     presence: true, inclusion: { in: USE_CASES }
  validates :room_layout,  presence: true, inclusion: { in: ROOM_LAYOUTS }
  validates :price_period, presence: true, inclusion: { in: PRICE_PERIODS }
  validates :price,        numericality: { greater_than: 0 }
  validates :viewing_fee,  numericality: { greater_than_or_equal_to: 0 }
  validates :status,       presence: true, inclusion: { in: STATUSES }

  scope :published,      -> { where(status: 'published') }
  scope :featured,       -> { where(featured: true) }
  scope :by_need_type,   ->(type) { where(need_type: type) if type.present? }
  scope :by_location,    ->(id)   { where(location_id: id) if id.present? }
  scope :by_country,     ->(val)  { joins(:location).where(locations: { country: val }) if val.present? }
  scope :by_county,      ->(val)  { joins(:location).where(locations: { county: val }) if val.present? }
  scope :by_sub_county,  ->(val)  { joins(:location).where(locations: { sub_county: val }) if val.present? }
  scope :by_area_name,   ->(val)  { joins(:location).where(locations: { area_name: val }) if val.present? }
  scope :by_use_case,    ->(uc)   { where(use_case: uc) if uc.present? }
  scope :by_room_layout, ->(rl)   { where(room_layout: rl) if rl.present? }
  scope :price_between,  ->(min, max) {
    scope = all
    scope = scope.where('price >= ?', min) if min.present?
    scope = scope.where('price <= ?', max) if max.present?
    scope
  }
  scope :sorted_by, ->(val) {
    case val
    when 'price_asc'  then order(price: :asc)
    when 'price_desc' then order(price: :desc)
    when 'newest'     then order(created_at: :desc)
    else                   order(created_at: :desc)
    end
  }
  scope :search_by_keyword, ->(keyword) {
    if keyword.present?
      sanitized = keyword.strip
      joins(:location).where(
        'listings.title ILIKE :q OR listings.description ILIKE :q OR listings.building_name ILIKE :q ' \
        'OR locations.area_name ILIKE :q OR locations.county ILIKE :q OR locations.sub_county ILIKE :q ' \
        'OR locations.country ILIKE :q',
        q: "%#{sanitized}%"
      )
    end
  }

  def publish!
    update!(status: 'published')
    begin
      ListingMailer.listing_published(self).deliver_now
    rescue => e
      Rails.logger.error("[ListingMailer] listing_published failed: #{e.class}: #{e.message}")
    end
  end

  def hide!
    update!(status: 'hidden')
  end
end
