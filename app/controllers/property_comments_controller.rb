class PropertyCommentsController < ApplicationController
  before_action :authenticate_user!
  before_action :set_listing

  def create
    @comment = @listing.property_comments.build(comment_params)
    @comment.author = current_user
    authorize! :create, @comment

    if @comment.save
      respond_to do |format|
        format.turbo_stream
        format.html { redirect_to listing_path(@listing) }
      end
    else
      redirect_to listing_path(@listing), alert: @comment.errors.full_messages.join(", ")
    end
  end

  def destroy
    @comment = @listing.property_comments.find(params[:id])
    authorize! :destroy, @comment
    @comment.destroy
    respond_to do |format|
      format.turbo_stream { render turbo_stream: turbo_stream.remove(@comment) }
      format.html { redirect_to listing_path(@listing), notice: t('property_comments.destroyed') }
    end
  end

  private

  def set_listing
    @listing = Listing.find(params[:listing_id])
  end

  def comment_params
    params.require(:property_comment).permit(:body, :parent_comment_id)
  end
end
