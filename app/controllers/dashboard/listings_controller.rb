module Dashboard
  class ListingsController < BaseController
    before_action :set_listing, only: [:edit, :update, :destroy, :publish, :hide]

    def index
      @listings = current_user.listings
                              .includes(:location, :property_images)
                              .sorted_by(params[:sort])
                              .page(params[:page])
                              .per(10)
    end

    def new
      @listing = current_user.listings.build
      @locations = Location.order(:area_name)
    end

    def create
      @listing = current_user.listings.build(listing_params)
      @listing.location = find_or_create_location

      ActiveRecord::Base.transaction do
        current_user.upgrade_to_agent! if current_user.home_seeker?
        @listing.save!
        attach_images!(@listing)
      end

      redirect_to listing_path(@listing), notice: t('listings.created')
    rescue ActiveRecord::RecordInvalid
      @locations = Location.order(:area_name)
      render :new, status: :unprocessable_entity
    end

    def edit
      authorize! :update, @listing
      @locations = Location.order(:area_name)
    end

    def update
      authorize! :update, @listing
      @listing.location = find_or_create_location if params[:county].present? && params[:area_name].present?

      if @listing.update(listing_params)
        attach_images!(@listing)
        redirect_to dashboard_listings_path, notice: t('listings.updated')
      else
        @locations = Location.order(:area_name)
        render :edit, status: :unprocessable_entity
      end
    end

    def destroy
      authorize! :destroy, @listing
      @listing.destroy
      redirect_to dashboard_listings_path, notice: t('listings.destroyed')
    end

    def publish
      authorize! :publish, @listing
      @listing.publish!
      redirect_to dashboard_listings_path, notice: t('listings.published')
    end

    def hide
      authorize! :hide, @listing
      @listing.hide!
      redirect_to dashboard_listings_path, notice: t('listings.hidden')
    end

    private

    def set_listing
      @listing = current_user.listings.find(params[:id])
    end

    def listing_params
      params.require(:listing).permit(
        :title, :description, :need_type, :use_case, :room_layout,
        :price, :price_period, :building_name, :location_id,
        :bathrooms, :viewing_fee, :status
      )
    end

    def find_or_create_location
      return nil unless params[:county].present? && params[:area_name].present?

      loc = location_params
      Location.find_or_create_by!(
        county:     loc[:county],
        sub_county: loc[:sub_county],
        area_name:  loc[:area_name],
        country:    loc[:country].presence || 'Kenya'
      )
    rescue ActiveRecord::RecordInvalid
      nil
    end

    def location_params
      params.permit(:county, :sub_county, :area_name, :country)
    end

    def attach_images!(listing)
      return unless params[:images].present?

      remaining = 8 - listing.property_images.count
      params[:images].first(remaining).each do |img|
        pi = listing.property_images.build
        pi.image.attach(img)
        pi.save!
      end
    end
  end
end
