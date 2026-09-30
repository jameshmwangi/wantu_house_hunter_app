# frozen_string_literal: true

require "rails_helper"

RSpec.describe "Api::V1::Payments", type: :request do
  let(:appointment) { create(:viewing_appointment, fee_amount: 500) }
  let(:escrow) { appointment.escrow_transaction_or_create! }

  # Pesapal IPN payload structure (confirmed from development1/PesaPal-main/pin.json):
  #   { "OrderTrackingId": "...", "OrderNotificationType": "IPNCHANGE", "OrderMerchantReference": "..." }
  #
  # Pesapal IPN response must be:
  #   { "orderNotificationType": "IPNCHANGE", "orderTrackingId": "...", "orderMerchantReference": "...", "status": 200 }

  describe "POST /api/v1/pesapal/ipn" do
    let(:order_tracking_id) { "cb7fec53-e20e-48de-8ebc-#{escrow.id.to_s.rjust(12, '0')}" }

    context "collection callback" do
      let!(:payment_tx) do
        escrow.payment_transactions.create!(
          direction:          "collection",
          provider:           "pesapal",
          provider_channel:   "mpesa",
          provider_reference: order_tracking_id,  # = Pesapal order_tracking_id
          status:             "pending",
          amount_cents:       escrow.amount_cents
        )
      end

      context "when GetTransactionStatus returns COMPLETED (status_code: 1)" do
        before do
          allow_any_instance_of(PesapalClient).to receive(:get_transaction_status)
            .with(order_tracking_id)
            .and_return({
              "payment_method"              => "MPESA",
              "amount"                      => 500,
              "status_code"                 => 1,
              "payment_status_description"  => "Completed",
              "confirmation_code"           => "NLJ7RT61SV",
              "status"                      => "200"
            })
        end

        it "funds the escrow and records ledger entries" do
          post "/api/v1/pesapal/ipn", params: {
            OrderTrackingId:        order_tracking_id,
            OrderNotificationType:  "IPNCHANGE",
            OrderMerchantReference: "BOOKING-#{escrow.id}-abcd"
          }, as: :json

          expect(response).to have_http_status(:ok)
          body = response.parsed_body
          expect(body["status"]).to eq(200)
          expect(body["orderTrackingId"]).to eq(order_tracking_id)

          expect(payment_tx.reload.status).to eq("success")
          expect(escrow.reload).to be_funded
          expect(escrow.ledger_entries.pluck(:account, :entry_type, :amount_cents)).to contain_exactly(
            ["home_seeker_suspense", "debit", 50_000],
            ["escrow_holding", "credit", 50_000]
          )
        end
      end

      context "when GetTransactionStatus returns FAILED (status_code: 2)" do
        before do
          allow_any_instance_of(PesapalClient).to receive(:get_transaction_status)
            .with(order_tracking_id)
            .and_return({ "status_code" => 2, "payment_status_description" => "Failed", "status" => "200" })
        end

        it "marks payment_transaction failed" do
          post "/api/v1/pesapal/ipn", params: {
            OrderTrackingId:        order_tracking_id,
            OrderNotificationType:  "IPNCHANGE",
            OrderMerchantReference: "BOOKING-#{escrow.id}-abcd"
          }, as: :json

          expect(response).to have_http_status(:ok)
          expect(payment_tx.reload.status).to eq("failed")
          expect(escrow.reload).to be_pending
        end
      end

      context "when GetTransactionStatus returns still pending (status_code: 0)" do
        before do
          allow_any_instance_of(PesapalClient).to receive(:get_transaction_status)
            .with(order_tracking_id)
            .and_return({ "status_code" => 0, "payment_status_description" => "Invalid", "status" => "200" })
        end

        it "leaves payment_transaction pending and responds 200" do
          post "/api/v1/pesapal/ipn", params: {
            OrderTrackingId:        order_tracking_id,
            OrderNotificationType:  "IPNCHANGE",
            OrderMerchantReference: "BOOKING-#{escrow.id}-abcd"
          }, as: :json

          expect(response).to have_http_status(:ok)
          expect(payment_tx.reload.status).to eq("pending")
        end
      end

      it "is idempotent if already processed" do
        payment_tx.update!(status: "success")
        escrow.update!(status: "funded")

        post "/api/v1/pesapal/ipn", params: {
          OrderTrackingId:        order_tracking_id,
          OrderNotificationType:  "IPNCHANGE",
          OrderMerchantReference: "BOOKING-#{escrow.id}-abcd"
        }, as: :json

        expect(response).to have_http_status(:ok)
        expect(response.parsed_body["status"]).to eq(200)
      end
    end

    context "missing OrderTrackingId" do
      it "responds 200 with orderTrackingId nil (does not crash)" do
        post "/api/v1/pesapal/ipn", params: {
          OrderNotificationType:  "IPNCHANGE",
          OrderMerchantReference: "BOOKING-unknown"
        }, as: :json

        expect(response).to have_http_status(:ok)
        expect(response.parsed_body["status"]).to eq(200)
      end
    end
  end
end
