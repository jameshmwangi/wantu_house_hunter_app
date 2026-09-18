class AgentsController < ApplicationController
  def show
    @agent = User.where(role: %w[agent landlord admin]).find(params[:id])
    @listings = @agent.listings.published
                      .includes(:location, :property_images)
                      .page(params[:page])
                      .per(6)
    @reviews = @agent.agent_reviews.includes(:author).order(created_at: :desc)
    @avg_rating = @agent.average_agent_rating
    @review_count = @agent.agent_reviews.count
    @favourite_ids_by_listing = current_user&.favourites&.pluck(:listing_id, :id)&.to_h || {}
  end
end
