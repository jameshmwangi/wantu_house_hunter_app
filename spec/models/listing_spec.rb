require 'rails_helper'

RSpec.describe Listing, type: :model do
  describe 'validations' do
    it 'is valid with all required fields from the factory' do
      expect(build(:listing)).to be_valid
    end

    describe 'title' do
      it 'is invalid when blank' do
        listing = build(:listing, title: '')
        expect(listing).not_to be_valid
        expect(listing.errors[:title]).to include("can't be blank")
      end
    end

    describe 'description' do
      it 'is invalid when blank' do
        listing = build(:listing, description: '')
        expect(listing).not_to be_valid
        expect(listing.errors[:description]).to include("can't be blank")
      end
    end

    describe 'price' do
      it 'is invalid when zero' do
        listing = build(:listing, price: 0)
        expect(listing).not_to be_valid
        expect(listing.errors[:price]).to include('must be greater than 0')
      end

      it 'is invalid when negative' do
        listing = build(:listing, price: -100)
        expect(listing).not_to be_valid
      end

      it 'is valid when positive' do
        expect(build(:listing, price: 25_000)).to be_valid
      end
    end

    describe 'viewing_fee' do
      it 'is valid when zero' do
        expect(build(:listing, viewing_fee: 0)).to be_valid
      end

      it 'is invalid when negative' do
        listing = build(:listing, viewing_fee: -50)
        expect(listing).not_to be_valid
      end
    end

    describe 'status' do
      it 'is invalid with an unknown status' do
        listing = build(:listing, status: 'archived')
        expect(listing).not_to be_valid
        expect(listing.errors[:status]).to include('is not included in the list')
      end

      Listing::STATUSES.each do |status|
        it "is valid with status #{status}" do
          expect(build(:listing, status: status)).to be_valid
        end
      end
    end

    describe 'need_type' do
      it 'is invalid with an unknown need_type' do
        listing = build(:listing, need_type: 'lease')
        expect(listing).not_to be_valid
        expect(listing.errors[:need_type]).to include('is not included in the list')
      end
    end

    describe 'use_case' do
      it 'is invalid with an unknown use_case' do
        listing = build(:listing, use_case: 'warehouse')
        expect(listing).not_to be_valid
        expect(listing.errors[:use_case]).to include('is not included in the list')
      end
    end

    describe 'room_layout' do
      it 'is invalid with an unknown room_layout' do
        listing = build(:listing, room_layout: 'penthouse')
        expect(listing).not_to be_valid
        expect(listing.errors[:room_layout]).to include('is not included in the list')
      end
    end

    describe 'price_period' do
      it 'is invalid with an unknown price_period' do
        listing = build(:listing, price_period: 'fortnight')
        expect(listing).not_to be_valid
        expect(listing.errors[:price_period]).to include('is not included in the list')
      end
    end
  end

  describe 'scopes' do
    let!(:location) { create(:location, county: 'Nairobi', sub_county: 'Westlands', area_name: 'Parklands', country: 'Kenya') }
    let!(:cheap)    { create(:listing, price: 10_000, status: 'published', location: location) }
    let!(:mid)      { create(:listing, price: 30_000, status: 'published', featured: true, location: location) }
    let!(:pricey)   { create(:listing, price: 80_000, status: 'draft', location: location) }

    describe '.published' do
      it 'returns only published listings' do
        expect(Listing.published).to contain_exactly(cheap, mid)
      end
    end

    describe '.featured' do
      it 'returns only featured listings' do
        expect(Listing.featured).to contain_exactly(mid)
      end
    end

    describe '.price_between' do
      it 'filters by min only' do
        expect(Listing.price_between(20_000, nil)).to contain_exactly(mid, pricey)
      end

      it 'filters by max only' do
        expect(Listing.price_between(nil, 30_000)).to contain_exactly(cheap, mid)
      end

      it 'filters by both' do
        expect(Listing.price_between(10_000, 30_000)).to contain_exactly(cheap, mid)
      end

      it 'returns all when both nil' do
        expect(Listing.price_between(nil, nil)).to contain_exactly(cheap, mid, pricey)
      end
    end

    describe '.sorted_by' do
      it 'sorts by price ascending' do
        expect(Listing.sorted_by('price_asc').pluck(:id)).to eq([cheap, mid, pricey].map(&:id))
      end

      it 'sorts by price descending' do
        expect(Listing.sorted_by('price_desc').pluck(:id)).to eq([pricey, mid, cheap].map(&:id))
      end

      it 'defaults to newest' do
        expect(Listing.sorted_by(nil).first).to eq(pricey)
      end
    end

    describe '.search_by_keyword' do
      it 'matches title' do
        cheap.update!(title: 'Cozy Studio Near CBD')
        expect(Listing.search_by_keyword('cozy')).to include(cheap)
      end

      it 'matches location area_name' do
        expect(Listing.search_by_keyword('Parklands')).to contain_exactly(cheap, mid, pricey)
      end

      it 'returns all when keyword blank' do
        expect(Listing.search_by_keyword('').count).to eq(3)
      end
    end

    describe '.by_need_type' do
      it 'filters by need_type' do
        bnb = create(:listing, :bnb, location: location)
        expect(Listing.by_need_type('bnb')).to contain_exactly(bnb)
      end

      it 'returns all when nil' do
        expect(Listing.by_need_type(nil).count).to eq(3)
      end
    end
  end

  describe '#publish!' do
    let(:listing) { create(:listing, :draft) }

    it 'sets status to published and delivers the listing_published email' do
      expect { listing.publish! }
        .to change { ActionMailer::Base.deliveries.count }.by(1)

      expect(listing.reload.status).to eq('published')
      expect(ActionMailer::Base.deliveries.last.to).to include(listing.user.email)
    end
  end

  describe '#hide!' do
    let(:listing) { create(:listing, status: 'published') }

    it 'sets status to hidden' do
      listing.hide!
      expect(listing.reload.status).to eq('hidden')
    end
  end
end
