require 'rails_helper'

RSpec.describe Location, type: :model do
  describe 'validations' do
    it 'is valid with area_name, county, and country' do
      expect(build(:location)).to be_valid
    end

    describe 'area_name' do
      it 'is invalid when blank' do
        location = build(:location, area_name: '')
        expect(location).not_to be_valid
        expect(location.errors[:area_name]).to include("can't be blank")
      end

      it 'is invalid when nil' do
        location = build(:location, area_name: nil)
        expect(location).not_to be_valid
        expect(location.errors[:area_name]).to include("can't be blank")
      end
    end

    describe 'county' do
      it 'is invalid when blank' do
        location = build(:location, county: '')
        expect(location).not_to be_valid
        expect(location.errors[:county]).to include("can't be blank")
      end

      it 'is invalid when nil' do
        location = build(:location, county: nil)
        expect(location).not_to be_valid
        expect(location.errors[:county]).to include("can't be blank")
      end
    end

    describe 'country' do
      it 'is invalid when blank' do
        location = build(:location, country: '')
        expect(location).not_to be_valid
        expect(location.errors[:country]).to include("can't be blank")
      end

      it 'is invalid when nil' do
        location = build(:location, country: nil)
        expect(location).not_to be_valid
        expect(location.errors[:country]).to include("can't be blank")
      end
    end
  end

  describe 'associations' do
    it 'destroys dependent listings when destroyed' do
      location = create(:location)
      create(:listing, location: location)
      expect { location.destroy }.to change { Listing.count }.by(-1)
    end
  end
end
