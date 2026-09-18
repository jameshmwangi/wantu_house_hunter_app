require 'rails_helper'

RSpec.describe "Email Notifications", type: :system do
  before { ActionMailer::Base.deliveries.clear }

  describe "welcome email on signup" do
    it "delivers a welcome email after registration" do
      visit new_user_registration_path

      fill_in I18n.t('devise.labels.full_name'), with: "New User"
      fill_in I18n.t('devise.labels.email'), with: "newuser@wantu.africa"
      fill_in I18n.t('devise.labels.phone_number'), with: "0700123456"
      select I18n.t('roles.home_seeker'), from: I18n.t('devise.labels.role')
      fill_in I18n.t('devise.labels.password'), with: "Password1"
      fill_in I18n.t('devise.labels.password_confirmation'), with: "Password1"

      expect {
        click_button I18n.t('devise.registrations.new.sign_up')
      }.to change { ActionMailer::Base.deliveries.count }.by(1)

      expect(ActionMailer::Base.deliveries.last.to).to include("newuser@wantu.africa")
    end

    it "does not deliver an email when registration fails" do
      visit new_user_registration_path

      expect {
        click_button I18n.t('devise.registrations.new.sign_up')
      }.not_to change { ActionMailer::Base.deliveries.count }
    end
  end
end
