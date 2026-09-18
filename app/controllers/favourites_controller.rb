class FavouritesController < ApplicationController
  before_action :authenticate_user!

  def index
    @favourites = current_user.favourites
                              .includes(listing: [:location, :property_images])
                              .page(params[:page])
                              .per(12)
  end

  def create
    @favourite = current_user.favourites.build(listing_id: params[:listing_id])
    authorize! :create, @favourite
    if @favourite.save
      redirect_back fallback_location: listings_path, notice: t('favourites.added')
    else
      redirect_back fallback_location: listings_path, alert: t('favourites.added')
    end
  end

  def destroy
    @favourite = current_user.favourites.find(params[:id])
    authorize! :destroy, @favourite
    @favourite.destroy
    redirect_back fallback_location: favourites_path, notice: t('favourites.removed')
  end
end
