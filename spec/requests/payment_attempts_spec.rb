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

  describe 'GET /payment_attempts/new' do
    it 'redirects to Pesapal checkout when payment attempt has a redirect_url' do
      fake_payment = instance_double(
        PaymentAttempt,
        redirect_url: 'https://pay.pesapal.com/v3/transactions/order/SubmitOrderRequest?OrderTrackingId=fake-123',
        outcome: 'pending'
      )
      allow_any_instance_of(ViewingAppointment).to receive(:initiate_pesapal_payment!)
        .and_return(fake_payment)

      get new_payment_attempt_path, params: { viewing_appointment_id: appointment.id }

      expect(response).to redirect_to('https://pay.pesapal.com/v3/transactions/order/SubmitOrderRequest?OrderTrackingId=fake-123')
    end

    it 'redirects to listing if appointment is already paid' do
      appointment.update!(fee_status: 'paid')

      get new_payment_attempt_path, params: { viewing_appointment_id: appointment.id }

      expect(response).to redirect_to(listing_path(listing))
      expect(flash[:alert]).to be_present
    end
  end
end
