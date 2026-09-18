module Dashboard
  class PropertyImagesController < BaseController
    before_action :set_listing

    def create
      @image = @listing.property_images.build
      @image.image.attach(params[:image])

      if @image.save
        redirect_to edit_dashboard_listing_path(@listing), notice: t('property_images.created')
      else
        redirect_to edit_dashboard_listing_path(@listing), alert: t('property_images.failed')
      end
    end

    def destroy
      @image = @listing.property_images.find(params[:id])
      @image.image.purge
      @image.destroy
      redirect_to edit_dashboard_listing_path(@listing), notice: t('property_images.destroyed')
    end

    private

    def set_listing
      @listing = current_user.listings.find(params[:listing_id])
    end
  end
end
