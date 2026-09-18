require 'rails_helper'

RSpec.describe "Listings", type: :system do
  let!(:location) { create(:location, area_name: "Westlands", county: "Nairobi") }
  let!(:agent) { create(:user, :agent) }

  describe "public browsing" do
    let!(:published_listing) do
      create(:listing, user: agent, location: location, title: "Modern Apartment",
             description: "Spacious and modern", status: "published", price: 30_000,
             building_name: nil)
    end
    let!(:draft_listing) do
      create(:listing, :draft, user: agent, location: location, title: "Hidden Draft")
    end

    it "displays published listings on the index page" do
      visit listings_path
      expect(page).to have_content("Modern Apartment")
      expect(page).not_to have_content("Hidden Draft")
    end

    it "shows the property detail page" do
      visit listing_path(published_listing)
      expect(page).to have_content("Modern Apartment")
      expect(page).to have_content("Spacious and modern")
      expect(page).to have_content("30,000")
    end
  end

  describe "search and filter" do
    let!(:rent_listing) do
      create(:listing, user: agent, location: location, title: "Rental Studio",
             need_type: "rent", room_layout: "studio", price: 15_000, status: "published")
    end
    let!(:buy_listing) do
      create(:listing, :for_sale, user: agent, location: location,
             title: "Villa for Sale", status: "published")
    end

    it "filters by need_type" do
      visit listings_path(need_type: "rent")
      expect(page).to have_content("Rental Studio")
      expect(page).not_to have_content("Villa for Sale")
    end

    it "filters by location" do
      other_location = create(:location, area_name: "Karen")
      create(:listing, user: agent, location: other_location, title: "Karen Home",
             status: "published")

      visit listings_path(location_id: location.id)
      expect(page).to have_content("Rental Studio")
      expect(page).not_to have_content("Karen Home")
    end

    it "filters by price range" do
      visit listings_path(min_price: 100_000)
      expect(page).to have_content("Villa for Sale")
      expect(page).not_to have_content("Rental Studio")
    end

    it "searches by keyword" do
      visit listings_path(keyword: "Studio")
      expect(page).to have_content("Rental Studio")
      expect(page).not_to have_content("Villa for Sale")
    end
  end

  describe "sorting" do
    let!(:cheap) do
      create(:listing, user: agent, location: location, title: "Cheap Place",
             price: 5_000, status: "published")
    end
    let!(:expensive) do
      create(:listing, user: agent, location: location, title: "Expensive Place",
             price: 50_000, status: "published")
    end

    it "sorts by price ascending" do
      visit listings_path(sort: "price_asc")
      expect(page.body.index("Cheap Place")).to be < page.body.index("Expensive Place")
    end

    it "sorts by price descending" do
      visit listings_path(sort: "price_desc")
      expect(page.body.index("Expensive Place")).to be < page.body.index("Cheap Place")
    end
  end

  describe "agent CRUD" do
    before { sign_in agent }

    it "creates a new listing" do
      visit new_dashboard_listing_path
      fill_in "Title", with: "New Test Listing"
      fill_in "Description", with: "A lovely test property" * 3
      select location.county, from: "county"
      select location.sub_county, from: "sub_county"
      fill_in "area_name", with: location.area_name
      fill_in "Price (KSh)", with: 25_000
      fill_in "Viewing Fee (KSh)", with: 200
      click_button "Publish Listing"

      expect(page).to have_content(I18n.t('listings.created'))
      expect(Listing.last.title).to eq("New Test Listing")
    end

    it "shows validation errors when creating with invalid data" do
      visit new_dashboard_listing_path
      click_button "Publish Listing"

      expect(page).to have_content("can't be blank")
    end

    it "lists own listings on dashboard" do
      listing = create(:listing, user: agent, location: location, title: "My Listing")
      visit dashboard_listings_path
      expect(page).to have_content("My Listing")
    end

    it "edits a listing" do
      listing = create(:listing, user: agent, location: location, title: "Old Title")
      visit edit_dashboard_listing_path(listing)
      fill_in "Title", with: "Updated Title"
      click_button "Update Listing"

      expect(page).to have_content(I18n.t('listings.updated'))
      expect(listing.reload.title).to eq("Updated Title")
    end

    it "deletes a listing" do
      listing = create(:listing, user: agent, location: location, title: "To Delete")
      visit dashboard_listings_path
      expect(page).to have_content("To Delete")

      click_button I18n.t('actions.delete')
      expect(page).to have_content(I18n.t('listings.destroyed'))
      expect(page).not_to have_content("To Delete")
    end

    it "publishes a draft listing" do
      listing = create(:listing, :draft, user: agent, location: location)
      visit dashboard_listings_path
      click_button I18n.t('listings.status.published')
      expect(page).to have_content(I18n.t('listings.published'))
      expect(listing.reload.status).to eq("published")
    end

    it "hides a published listing" do
      listing = create(:listing, user: agent, location: location, status: "published")
      visit dashboard_listings_path
      click_button I18n.t('listings.status.hidden')
      expect(page).to have_content(I18n.t('listings.hidden'))
      expect(listing.reload.status).to eq("hidden")
    end
  end

  describe "access restrictions" do
    it "redirects unauthenticated users from dashboard" do
      visit dashboard_listings_path
      expect(page).to have_current_path(new_user_session_path)
    end

    it "prevents non-owner from editing another agent's listing" do
      other_agent = create(:user, :agent)
      listing = create(:listing, user: other_agent, location: location)
      sign_in agent

      visit edit_dashboard_listing_path(listing)
      expect(page).to have_content(I18n.t('errors.not_found'))
    end
  end

  describe "role auto-upgrade" do
    let(:home_seeker) { create(:user, role: "home_seeker") }

    it "upgrades home_seeker to agent on first listing creation" do
      sign_in home_seeker
      visit new_dashboard_listing_path

      fill_in "Title", with: "My First Listing"
      fill_in "Description", with: "Home seeker creates a listing"
      select location.county, from: "county"
      select location.sub_county, from: "sub_county"
      fill_in "area_name", with: location.area_name
      fill_in "Price (KSh)", with: 20_000
      fill_in "Viewing Fee (KSh)", with: 0
      click_button "Publish Listing"

      expect(home_seeker.reload.role).to eq("agent")
    end
  end
end
