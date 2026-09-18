require 'rails_helper'

RSpec.describe AgentReview, type: :model do
  let(:agent)  { create(:user, :agent) }
  let(:author) { create(:user) }

  def build_review(**overrides)
    build(:agent_review, agent: agent, author: author, **overrides)
  end

  describe 'validations' do
    describe 'rating' do
      it 'is valid with a rating of 1' do
        expect(build_review(rating: 1)).to be_valid
      end

      it 'is valid with a rating of 5' do
        expect(build_review(rating: 5)).to be_valid
      end

      it 'is invalid when rating is 0 (below range)' do
        review = build_review(rating: 0)
        expect(review).not_to be_valid
        expect(review.errors[:rating]).to be_present
      end

      it 'is invalid when rating is 6 (above range)' do
        review = build_review(rating: 6)
        expect(review).not_to be_valid
        expect(review.errors[:rating]).to be_present
      end

      it 'is invalid when rating is negative' do
        review = build_review(rating: -1)
        expect(review).not_to be_valid
      end

      it 'is invalid when rating is not an integer' do
        review = build_review(rating: 3.5)
        expect(review).not_to be_valid
      end

      it 'is invalid when rating is nil' do
        review = build_review(rating: nil)
        expect(review).not_to be_valid
        expect(review.errors[:rating]).to include("can't be blank")
      end
    end

    describe 'body' do
      it 'is valid when present' do
        expect(build_review(body: 'Excellent service.')).to be_valid
      end

      it 'is invalid when blank' do
        review = build_review(body: '')
        expect(review).not_to be_valid
        expect(review.errors[:body]).to include("can't be blank")
      end

      it 'is invalid when nil' do
        review = build_review(body: nil)
        expect(review).not_to be_valid
        expect(review.errors[:body]).to include("can't be blank")
      end
    end

    describe 'associations' do
      it 'requires an agent' do
        review = build(:agent_review, agent: nil, author: author, rating: 4, body: 'ok')
        expect(review).not_to be_valid
        expect(review.errors[:agent]).to be_present
      end

      it 'requires an author' do
        review = build(:agent_review, agent: agent, author: nil, rating: 4, body: 'ok')
        expect(review).not_to be_valid
        expect(review.errors[:author]).to be_present
      end
    end
  end
end
