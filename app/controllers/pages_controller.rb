class PagesController < ApplicationController
  LOCATION_CARDS = [
    { area: 'Juja',    image: 'jujaherocard.png' },
    { area: 'Karen',   image: 'KAREN_hero_card.png' },
    { area: 'Mombasa', image: 'Mombasa_hero_card.png' },
    { area: 'Rongai',  image: 'RONGAI_hero_card.png' }
  ].freeze

  def home
    @featured_listings = Listing.includes(:location, :property_images)
                                .published
                                .featured
                                .limit(6)

    locations_by_name = Location.where(area_name: LOCATION_CARDS.map { |c| c[:area] })
                                .index_by(&:area_name)
    @location_cards = LOCATION_CARDS.map { |card| card.merge(location: locations_by_name[card[:area]]) }
    @favourite_ids_by_listing = current_user&.favourites&.pluck(:listing_id, :id)&.to_h || {}
  end
end
