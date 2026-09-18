require 'rails_helper'

RSpec.describe "Authentication", type: :system do
  describe "sign up" do
    it "registers a new user with role selection" do
      visit new_user_registration_path

      fill_in I18n.t('devise.labels.full_name'), with: "Jane Wanjiku"
      fill_in I18n.t('devise.labels.email'), with: "jane@wantu.africa"
      fill_in I18n.t('devise.labels.phone_number'), with: "0712345678"
      select I18n.t('roles.agent'), from: I18n.t('devise.labels.role')
      fill_in I18n.t('devise.labels.password'), with: "Password1"
      fill_in I18n.t('devise.labels.password_confirmation'), with: "Password1"
      click_button I18n.t('devise.registrations.new.sign_up')

      user = User.find_by(email: "jane@wantu.africa")
      expect(user).to be_present
      expect(user.role).to eq("agent")
      expect(user.full_name).to eq("Jane Wanjiku")
    end

    it "shows errors for invalid registration" do
      visit new_user_registration_path
      click_button I18n.t('devise.registrations.new.sign_up')

      expect(page).to have_content("Email can't be blank")
    end
  end

  describe "sign in" do
    let!(:user) { create(:user, email: "bob@wantu.africa", password: "Password1") }

    it "logs in with valid credentials" do
      visit new_user_session_path
      fill_in I18n.t('devise.labels.email'), with: "bob@wantu.africa"
      fill_in I18n.t('devise.labels.password'), with: "Password1"
      click_button I18n.t('devise.sessions.new.sign_in')

      expect(page).to have_current_path(root_path)
    end

    it "shows error for invalid credentials" do
      visit new_user_session_path
      fill_in I18n.t('devise.labels.email'), with: "bob@wantu.africa"
      fill_in I18n.t('devise.labels.password'), with: "wrong"
      click_button I18n.t('devise.sessions.new.sign_in')

      expect(page).to have_content("Invalid Email or password")
    end
  end

  describe "sign out" do
    let!(:user) { create(:user) }

    it "logs out the user" do
      sign_in user
      visit root_path
      click_on I18n.t('nav.logout'), match: :first

      expect(page).to have_content(I18n.t('nav.login'))
    end
  end
end
