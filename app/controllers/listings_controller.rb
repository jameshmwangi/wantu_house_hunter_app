class ListingsController < ApplicationController
  # Public listings: index (search/filter/sort) and show

  def index
    @listings = Listing.published
                       .includes(:location, :property_images)
                       .by_need_type(params[:need_type])
                       .by_location(params[:location_id])
                       .by_country(params[:country])
                       .by_county(params[:county])
                       .by_sub_county(params[:sub_county])
                       .by_area_name(params[:area_name])
                       .by_use_case(params[:use_case])
                       .by_room_layout(params[:room_layout])
                       .price_between(params[:min_price], params[:max_price])
                       .search_by_keyword(params[:keyword])
                       .sorted_by(params[:sort])
                       .page(params[:page])
                       .per(12)

    @favourite_ids_by_listing = current_user&.favourites&.pluck(:listing_id, :id)&.to_h || {}
    @locations = Location.order(:area_name)
  end

  def show
    @listing = Listing.includes(:location, :property_images, :property_comments)
                      .find(params[:id])
    authorize! :read, @listing
    @top_level_comments = @listing.property_comments
                                  .includes(:author, replies: :author)
                                  .where(parent_comment_id: nil)
                                  .order(created_at: :desc)
    @agent_listing_count = @listing.user.listings.published.count
    @images = @listing.property_images.select { |pi| pi.image.attached? }
    @favourite = current_user&.favourites&.find_by(listing_id: @listing.id)
  end
end
