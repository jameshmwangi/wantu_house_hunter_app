require 'rails_helper'

RSpec.describe ViewingAppointment, type: :model do
  let(:appointment) { create(:viewing_appointment) }

  describe '#transition_to!' do
    %w[confirm decline complete].each do |action|
      it "transitions to #{ViewingAppointment::TRANSITION_STATUSES[action]} and enqueues mailer" do
        expect { appointment.transition_to!(action) }
          .to have_enqueued_job(ActionMailer::MailDeliveryJob)

        expect(appointment.reload.status).to eq(ViewingAppointment::TRANSITION_STATUSES[action])
      end
    end

    it 'raises KeyError for unknown action' do
      expect { appointment.transition_to!('invalid') }.to raise_error(KeyError)
    end
  end

  describe '#process_payment!' do
    it 'creates a successful payment, updates fee_status, and enqueues mailers' do
      expect {
        payment = appointment.process_payment!(payment_method: 'mpesa', simulation: 'success')
        expect(payment.outcome).to eq('success')
        expect(payment.payment_reference).to start_with('WTU-')
      }.to change { appointment.payment_attempts.count }.by(1)

      expect(appointment.reload.fee_status).to eq('paid')
    end

    it 'creates a failed payment without updating fee_status' do
      payment = appointment.process_payment!(payment_method: 'mpesa', simulation: 'fail')

      expect(payment.outcome).to eq('failed')
      expect(payment.payment_reference).to be_nil
      expect(appointment.reload.fee_status).to eq('unpaid')
    end
  end
end
