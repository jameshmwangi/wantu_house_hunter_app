class DashboardController < ApplicationController
  before_action :authenticate_user!

  def index
    if current_user.property_manager?
      @active_listings_count = current_user.active_listings_count
      @booking_requests_count = current_user.booking_requests_count
      @fees_this_month = current_user.fees_this_month
      @avg_rating = current_user.average_agent_rating
      @available_kes = current_user.available_payable_cents("KES")
      @available_ugx = current_user.available_payable_cents("UGX")

      @listings = current_user.listings
                              .includes(:location, :property_images)
                              .sorted_by(params[:sort])
                              .page(params[:page])
                              .per(10)
    else
      redirect_to root_path
    end
  end
end
