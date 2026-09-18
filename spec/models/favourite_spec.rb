require 'rails_helper'

RSpec.describe Favourite, type: :model do
  let(:user)    { create(:user) }
  let(:listing) { create(:listing) }

  describe 'validations' do
    it 'is valid with a unique user/listing pair' do
      expect(build(:favourite, user: user, listing: listing)).to be_valid
    end

    describe 'listing_id uniqueness scoped to user_id' do
      it 'is invalid when the same user favourites the same listing twice' do
        create(:favourite, user: user, listing: listing)
        duplicate = build(:favourite, user: user, listing: listing)
        expect(duplicate).not_to be_valid
        expect(duplicate.errors[:listing_id]).to include('has already been taken')
      end

      it 'is valid when a different user favourites the same listing' do
        create(:favourite, user: user, listing: listing)
        other_user = create(:user)
        expect(build(:favourite, user: other_user, listing: listing)).to be_valid
      end

      it 'is valid when the same user favourites a different listing' do
        create(:favourite, user: user, listing: listing)
        other_listing = create(:listing)
        expect(build(:favourite, user: user, listing: other_listing)).to be_valid
      end
    end

    describe 'associations' do
      it 'requires a user' do
        favourite = build(:favourite, user: nil, listing: listing)
        expect(favourite).not_to be_valid
      end

      it 'requires a listing' do
        favourite = build(:favourite, user: user, listing: nil)
        expect(favourite).not_to be_valid
      end
    end
  end
end
