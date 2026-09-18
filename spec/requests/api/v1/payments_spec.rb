# frozen_string_literal: true

require "rails_helper"

RSpec.describe "Api::V1::Payments", type: :request do
  let(:appointment) { create(:viewing_appointment, fee_amount: 500) }
  let(:escrow) { appointment.escrow_transaction_or_create! }

  describe "POST /api/v1/payments/jenga_ipn" do
    context "collection callback" do
      let!(:payment_tx) do
        escrow.payment_transactions.create!(
          direction: "collection",
          provider: "jenga",
          provider_channel: "mpesa",
          provider_reference: "PR-#{escrow.id}-abc",
          status: "pending",
          amount_cents: escrow.amount_cents
        )
      end

      it "funds the escrow and records ledger entries on SUCCESS" do
        post "/api/v1/payments/jenga_ipn", params: {
          transaction: {
            reference: "PR-#{escrow.id}-abc",
            status: "SUCCESS"
          }
        }, as: :json

        expect(response).to have_http_status(:ok)
        expect(response.parsed_body).to eq({ "status" => "received" })

        expect(payment_tx.reload.status).to eq("success")
        expect(escrow.reload).to be_funded
        expect(escrow.ledger_entries.pluck(:account, :entry_type, :amount_cents)).to contain_exactly(
          ["home_seeker_suspense", "debit", 50_000],
          ["escrow_holding", "credit", 50_000]
        )
      end

      it "marks payment_transaction failed on failure" do
        post "/api/v1/payments/jenga_ipn", params: {
          transaction: {
            reference: "PR-#{escrow.id}-abc",
            status: "FAILED"
          }
        }, as: :json

        expect(response).to have_http_status(:ok)
        expect(payment_tx.reload.status).to eq("failed")
        expect(escrow.reload).to be_pending
      end

      it "is idempotent if already processed" do
        payment_tx.update!(status: "success")
        escrow.update!(status: "funded")

        post "/api/v1/payments/jenga_ipn", params: {
          transaction: {
            reference: "PR-#{escrow.id}-abc",
            status: "SUCCESS"
          }
        }, as: :json

        expect(response).to have_http_status(:ok)
      end
    end

    context "payout callback" do
      let(:agent) { appointment.agent }
      let!(:payout_account) do
        PayoutAccount.create!(
          agent: agent,
          country: "KE",
          kind: "mpesa",
          details: "254712345678",
          verified: true
        )
      end
      let!(:funded_and_released_escrow) do
        esc = appointment.escrow_transaction_or_create!
        esc.fund!
        esc.release!(code: esc.confirmation_code)
        esc
      end
      let!(:withdrawal) do
        w = Withdrawal.create!(
          agent: agent,
          payout_account: payout_account,
          amount_cents: 20_000,
          currency: "KES",
          status: "requested"
        )
        pt = PaymentTransaction.create!(
          escrow_transaction: funded_and_released_escrow,
          direction: "payout",
          provider: "jenga",
          provider_channel: "mpesa",
          provider_reference: "WD-#{w.id}-xyz",
          status: "pending",
          amount_cents: 20_000
        )
        w.update!(status: "processing", payment_transaction: pt)
        w
      end

      it "marks withdrawal paid and writes ledger entries on SUCCESS" do
        post "/api/v1/payments/jenga_ipn", params: {
          data: {
            transReference: "WD-#{withdrawal.id}-xyz",
            ResponseCode: "0"
          }
        }, as: :json

        expect(response).to have_http_status(:ok)
        expect(withdrawal.reload.status).to eq("paid")
        expect(funded_and_released_escrow.ledger_entries.where(account: %w[agent_payable cash_out]).count).to eq(2)
      end

      it "marks withdrawal failed on error without writing ledger entries" do
        post "/api/v1/payments/jenga_ipn", params: {
          data: {
            transReference: "WD-#{withdrawal.id}-xyz",
            ResponseCode: "1"
          }
        }, as: :json

        expect(response).to have_http_status(:ok)
        expect(withdrawal.reload.status).to eq("failed")
      end
    end

    context "HTTP Basic Authentication" do
      let!(:payment_tx) do
        escrow.payment_transactions.create!(
          direction: "collection",
          provider: "jenga",
          provider_channel: "mpesa",
          provider_reference: "PR-#{escrow.id}-auth",
          status: "pending",
          amount_cents: escrow.amount_cents
        )
      end

      before do
        allow(Rails.application.config).to receive(:jenga).and_return({
          environment: "sandbox",
          ipn_username: "correct_user",
          ipn_password: "correct_password"
        })
      end

      it "rejects requests with missing or invalid credentials" do
        post "/api/v1/payments/jenga_ipn", params: {
          transaction: { reference: "PR-#{escrow.id}-auth", status: "SUCCESS" }
        }, headers: { "HTTP_AUTHORIZATION" => ActionController::HttpAuthentication::Basic.encode_credentials("wrong", "credentials") }

        expect(response).to have_http_status(:unauthorized)
      end

      it "accepts requests with valid credentials" do
        post "/api/v1/payments/jenga_ipn", params: {
          transaction: { reference: "PR-#{escrow.id}-auth", status: "SUCCESS" }
        }, headers: { "HTTP_AUTHORIZATION" => ActionController::HttpAuthentication::Basic.encode_credentials("correct_user", "correct_password") }

        expect(response).to have_http_status(:ok)
      end
    end
  end
end
