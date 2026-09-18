require 'rails_helper'

RSpec.describe PaymentAttempt, type: :model do
  describe 'validations' do
    describe 'payment_method' do
      it 'is valid with mpesa' do
        expect(build(:payment_attempt, payment_method: 'mpesa')).to be_valid
      end

      it 'is valid with card' do
        expect(build(:payment_attempt, payment_method: 'card')).to be_valid
      end

      it 'is invalid with an unknown payment_method' do
        attempt = build(:payment_attempt, payment_method: 'bitcoin')
        expect(attempt).not_to be_valid
        expect(attempt.errors[:payment_method]).to include('is not included in the list')
      end

      it 'is invalid when blank' do
        attempt = build(:payment_attempt, payment_method: '')
        expect(attempt).not_to be_valid
        expect(attempt.errors[:payment_method]).to include("can't be blank")
      end

      it 'is invalid when nil' do
        attempt = build(:payment_attempt, payment_method: nil)
        expect(attempt).not_to be_valid
      end
    end

    describe 'outcome' do
      it 'is valid with success' do
        expect(build(:payment_attempt, outcome: 'success')).to be_valid
      end

      it 'is valid with failed' do
        expect(build(:payment_attempt, outcome: 'failed')).to be_valid
      end

      it 'is valid with pending' do
        expect(build(:payment_attempt, outcome: 'pending')).to be_valid
      end

      it 'is invalid with an unknown outcome' do
        attempt = build(:payment_attempt, outcome: 'cancelled')
        expect(attempt).not_to be_valid
        expect(attempt.errors[:outcome]).to include('is not included in the list')
      end

      it 'is invalid when blank' do
        attempt = build(:payment_attempt, outcome: '')
        expect(attempt).not_to be_valid
        expect(attempt.errors[:outcome]).to include("can't be blank")
      end
    end
  end

  describe 'scopes' do
    let!(:winner)  { create(:payment_attempt, outcome: 'success') }
    let!(:loser)   { create(:payment_attempt, outcome: 'failed') }
    let!(:waiting) { create(:payment_attempt, outcome: 'pending') }

    describe '.successful' do
      it 'returns only success outcomes' do
        expect(PaymentAttempt.successful).to contain_exactly(winner)
      end
    end

    describe '.failed' do
      it 'returns only failed outcomes' do
        expect(PaymentAttempt.failed).to contain_exactly(loser)
      end
    end

    describe '.pending_outcome' do
      it 'returns only pending outcomes' do
        expect(PaymentAttempt.pending_outcome).to contain_exactly(waiting)
      end
    end
  end
end
