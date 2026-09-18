require 'rails_helper'

RSpec.describe "Account Management", type: :system do
  let!(:user) { create(:user, full_name: "Alice Mwangi", phone_number: "0700111222") }

  describe "view profile" do
    it "displays the user's account details" do
      sign_in user
      visit account_path

      expect(page).to have_content("Alice Mwangi")
      expect(page).to have_content(user.email)
      expect(page).to have_content("0700111222")
    end

    it "redirects unauthenticated users to login" do
      visit account_path
      expect(page).to have_current_path(new_user_session_path)
    end
  end

  describe "edit profile" do
    before { sign_in user }

    it "updates full name and phone number" do
      visit edit_account_path
      fill_in I18n.t('devise.labels.full_name'), with: "Alice Updated"
      fill_in I18n.t('devise.labels.phone_number'), with: "0711999888"
      click_button I18n.t('users.update_profile')

      expect(page).to have_content(I18n.t('users.updated'))
      expect(user.reload.full_name).to eq("Alice Updated")
      expect(user.reload.phone_number).to eq("0711999888")
    end

    it "shows validation errors for blank full name" do
      visit edit_account_path
      fill_in I18n.t('devise.labels.full_name'), with: ""
      click_button I18n.t('users.update_profile')

      expect(page).to have_content("can't be blank")
    end
  end
end
