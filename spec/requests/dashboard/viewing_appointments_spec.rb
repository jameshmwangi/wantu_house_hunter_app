require 'rails_helper'

RSpec.describe 'Dashboard::ViewingAppointments', type: :request do
  let(:agent) { create(:user, :agent) }
  let(:listing) { create(:listing, user: agent) }
  let(:appointment) { create(:viewing_appointment, listing: listing, agent: agent, status: 'pending') }

  before { sign_in agent }

  describe 'PATCH /dashboard/appointments/:id' do
    it 'confirms an appointment' do
      patch dashboard_appointment_path(appointment), params: { status_action: 'confirm' }

      expect(appointment.reload.status).to eq('confirmed')
      expect(response).to redirect_to(dashboard_appointments_path)
    end

    it 'declines an appointment' do
      patch dashboard_appointment_path(appointment), params: { status_action: 'decline' }

      expect(appointment.reload.status).to eq('declined')
    end

    it 'rejects invalid actions' do
      patch dashboard_appointment_path(appointment), params: { status_action: 'destroy' }

      expect(appointment.reload.status).to eq('pending')
      expect(response).to redirect_to(dashboard_appointments_path)
    end
  end
end
