class AgentReviewsController < ApplicationController
  before_action :authenticate_user!
  before_action :set_review, only: [:edit, :update, :destroy]

  def new
    @agent = User.find(params[:agent_id])
    @review = AgentReview.new(agent: @agent)
    authorize! :create, @review
  end

  def create
    @review = AgentReview.new(review_params)
    @review.author = current_user
    authorize! :create, @review

    if @review.save
      redirect_to agent_profile_path(@review.agent), notice: t('agent_reviews.created')
    else
      @agent = @review.agent
      render :new, status: :unprocessable_entity
    end
  end

  def edit
    authorize! :update, @review
    @agent = @review.agent
  end

  def update
    authorize! :update, @review
    if @review.update(review_params)
      redirect_to agent_profile_path(@review.agent), notice: t('agent_reviews.updated')
    else
      @agent = @review.agent
      render :edit, status: :unprocessable_entity
    end
  end

  def destroy
    authorize! :destroy, @review
    agent = @review.agent
    @review.destroy
    redirect_to agent_profile_path(agent), notice: t('agent_reviews.destroyed')
  end

  private

  def set_review
    @review = AgentReview.find(params[:id])
  end

  def review_params
    params.require(:agent_review).permit(:agent_id, :rating, :title, :body)
  end
end
