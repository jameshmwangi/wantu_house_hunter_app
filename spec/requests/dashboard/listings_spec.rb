require 'rails_helper'

RSpec.describe 'Dashboard::Listings', type: :request do
  let(:agent) { create(:user, :agent) }
  let(:location) { create(:location) }

  before { sign_in agent }

  describe 'POST /dashboard/listings' do
    let(:valid_params) do
      {
        listing: {
          title: 'New Apartment',
          description: 'A modern apartment',
          need_type: 'rent',
          use_case: 'house',
          room_layout: 'one_bedroom',
          price: 25_000,
          price_period: 'month',
          viewing_fee: 500,
          building_name: 'Test Building'
        },
        area_name: 'Kilimani',
        county: 'Nairobi',
        sub_county: 'Dagoretti',
        country: 'Kenya'
      }
    end

    it 'creates a listing and redirects to the listing show page' do
      expect {
        post dashboard_listings_path, params: valid_params
      }.to change(Listing, :count).by(1)

      expect(response).to redirect_to(listing_path(Listing.last))
    end
  end

  describe 'PATCH /dashboard/listings/:id/publish' do
    let(:listing) { create(:listing, :draft, user: agent) }

    before { ActionMailer::Base.deliveries.clear }

    it 'publishes the listing and delivers the listing_published mailer' do
      expect {
        patch publish_dashboard_listing_path(listing)
      }.to change { ActionMailer::Base.deliveries.count }.by(1)

      expect(listing.reload.status).to eq('published')
      expect(response).to redirect_to(dashboard_listings_path)
    end
  end

  describe 'PATCH /dashboard/listings/:id/hide' do
    let(:listing) { create(:listing, user: agent, status: 'published') }

    it 'hides the listing' do
      patch hide_dashboard_listing_path(listing)

      expect(listing.reload.status).to eq('hidden')
      expect(response).to redirect_to(dashboard_listings_path)
    end
  end

  context 'when unauthorized' do
    let(:seeker) { create(:user, role: 'home_seeker') }

    before { sign_in seeker }

    it 'blocks home_seeker from publishing' do
      listing = create(:listing, :draft, user: seeker)
      patch publish_dashboard_listing_path(listing)

      expect(response).to redirect_to(root_path)
    end
  end
end
