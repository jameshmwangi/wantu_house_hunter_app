require 'rails_helper'

RSpec.describe 'PaymentAttempts', type: :request do
  let(:seeker) { create(:user, role: 'home_seeker') }
  let(:listing) { create(:listing) }
  let(:appointment) { create(:viewing_appointment, listing: listing, home_seeker: seeker, status: 'confirmed') }

  before { sign_in seeker }

  describe 'POST /payment_attempts' do
    it 'processes a successful payment' do
      expect {
        post payment_attempts_path, params: {
          viewing_appointment_id: appointment.id,
          payment_method: 'mpesa',
          payment_simulation: 'success'
        }
      }.to change(PaymentAttempt, :count).by(1)

      expect(appointment.reload.fee_status).to eq('paid')
      expect(response).to redirect_to(listing_path(listing))
    end

    it 'handles a failed payment' do
      post payment_attempts_path, params: {
        viewing_appointment_id: appointment.id,
        payment_method: 'mpesa',
        payment_simulation: 'fail'
      }

      expect(appointment.reload.fee_status).to eq('unpaid')
      expect(response).to redirect_to(listing_path(listing))
    end

    it 'blocks duplicate payment on already-paid appointment' do
      appointment.update!(fee_status: 'paid')

      post payment_attempts_path, params: {
        viewing_appointment_id: appointment.id,
        payment_method: 'mpesa',
        payment_simulation: 'success'
      }

      expect(response).to redirect_to(listing_path(listing))
      expect(flash[:alert]).to be_present
    end
  end
end
