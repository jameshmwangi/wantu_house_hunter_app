require 'rails_helper'
require 'cancan/matchers'

RSpec.describe Ability, type: :model do
  subject(:ability) { described_class.new(user) }

  describe 'guest (not signed in)' do
    let(:user) { nil }

    it { is_expected.to be_able_to(:read, build(:listing, status: 'published')) }
    it { is_expected.not_to be_able_to(:read, build(:listing, status: 'draft')) }
    it { is_expected.to be_able_to(:read, Location.new) }
    it { is_expected.to be_able_to(:read, AgentReview.new) }
    it { is_expected.to be_able_to(:read, PropertyComment.new) }
    it { is_expected.not_to be_able_to(:create, Listing.new) }
    it { is_expected.not_to be_able_to(:create, Favourite.new) }
    it { is_expected.not_to be_able_to(:create, ViewingAppointment.new) }
  end

  describe 'home_seeker' do
    let(:user) { create(:user, role: 'home_seeker') }

    it { is_expected.to be_able_to(:create, Listing.new) }
    it { is_expected.to be_able_to(:create, Favourite.new) }
    it { is_expected.to be_able_to(:destroy, build(:favourite, user: user)) }
    it { is_expected.not_to be_able_to(:destroy, build(:favourite, user: create(:user))) }
    it { is_expected.to be_able_to(:create, PropertyComment.new) }
    it { is_expected.to be_able_to(:create, ViewingAppointment.new) }
    it { is_expected.to be_able_to(:create, AgentReview.new) }
    it { is_expected.to be_able_to(:create, PaymentAttempt.new) }

    it 'cannot book own listing' do
      listing = create(:listing, user: user)
      appointment = build(:viewing_appointment, listing: listing)
      expect(ability).not_to be_able_to(:create, appointment)
    end

    it { is_expected.not_to be_able_to(:update, build(:listing, user: user)) }
    it { is_expected.not_to be_able_to(:publish, build(:listing, user: user)) }
    it { is_expected.not_to be_able_to(:access, :dashboard) }
  end

  describe 'agent (property_manager)' do
    let(:user) { create(:user, :agent) }

    it { is_expected.to be_able_to(:access, :dashboard) }
    it { is_expected.to be_able_to(:update, build(:listing, user: user)) }
    it { is_expected.to be_able_to(:destroy, build(:listing, user: user)) }
    it { is_expected.to be_able_to(:publish, build(:listing, user: user)) }
    it { is_expected.to be_able_to(:hide, build(:listing, user: user)) }
    it { is_expected.not_to be_able_to(:update, build(:listing, user: create(:user, :agent))) }

    it { is_expected.to be_able_to(:read, build(:listing, user: user, status: 'draft')) }

    it 'can manage own appointments as agent' do
      appt = build(:viewing_appointment, agent: user)
      expect(ability).to be_able_to(:read, appt)
      expect(ability).to be_able_to(:confirm, appt)
      expect(ability).to be_able_to(:decline, appt)
      expect(ability).to be_able_to(:complete, appt)
    end

    it 'cannot manage other agents appointments' do
      appt = build(:viewing_appointment, agent: create(:user, :agent))
      expect(ability).not_to be_able_to(:confirm, appt)
    end
  end

  describe 'admin' do
    let(:user) { create(:user, :admin) }

    it { is_expected.to be_able_to(:manage, :all) }
    it { is_expected.to be_able_to(:access, :admin_dashboard) }
  end
end
