require 'rails_helper'

RSpec.describe "Admin Dashboard", type: :system do
  let!(:admin) { create(:user, :admin) }
  let!(:regular_user) { create(:user) }
  let!(:location) { create(:location) }
  let!(:listing) { create(:listing, user: create(:user, :agent), location: location, status: "published") }

  describe "admin access" do
    it "allows admin to view the dashboard" do
      sign_in admin
      visit rails_admin.dashboard_path

      expect(page).to have_content("Platform Overview")
    end

    it "does not expose admin routes to non-admin users" do
      sign_in regular_user

      expect { visit "/admin" }.to raise_error(ActionController::RoutingError)
    end
  end
end
