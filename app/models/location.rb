class Location < ApplicationRecord
  has_many :listings, dependent: :destroy

  validates :area_name, presence: true
  validates :county, presence: true
  validates :country, presence: true
end
