# frozen_string_literal: true

module Api
  module V1
    # Handles Jenga API payment lifecycle:
    #   POST /api/v1/escrow_transactions/:escrow_transaction_id/pay  — initiate collection
    #   POST /api/v1/payments/ipn                                    — Jenga collection IPN callback
    #   POST /api/v1/payouts/ipn                                     — Jenga payout IPN callback
    #
    # IPN endpoints skip CSRF (server-to-server callbacks from Jenga) and always
    # respond with { status: "received" } so Jenga stops retrying on any outcome.
    #
    # Register IPN URLs in JengaHQ -> Settings -> IPNs (sandbox and production separately):
    #   https://<domain>/api/v1/payments/ipn
    #   https://<domain>/api/v1/payouts/ipn
    class PaymentsController < ApplicationController
      # IPN endpoints are called by Jenga's servers — skip CSRF for those actions.
      protect_from_forgery with: :null_session, only: [:ipn, :payout_ipn]

      before_action :authenticate_user!, only: [:create]

      # POST /api/v1/escrow_transactions/:escrow_transaction_id/pay
      #
      # Initiates an M-Pesa STK Push (Kenya) or MoMo collection (Uganda).
      # Creates a pending PaymentTransaction. The actual funded status arrives
      # via #ipn once Jenga's IPN fires on the home seeker's confirmation.
      def create
        escrow = EscrowTransaction.find(params[:escrow_transaction_id])

        # Guard: only the assigned home seeker can pay
        unless escrow.home_seeker_id == current_user.id
          return render json: { error: "Not authorized" }, status: :forbidden
        end

        # Guard: must be in pending status
        unless escrow.pending?
          return render json: { error: "Escrow is not in a payable state" }, status: :unprocessable_entity
        end

        # Zero-amount: short-circuit — no gateway call needed (design doc §1.4)
        if escrow.amount_cents.zero?
          escrow.fund!
          return render json: { status: "funded", message: "Zero-amount escrow funded immediately" }
        end

        adapter = PaymentGatewayAdapter.new
        result  = adapter.initiate_collection(
          escrow,
          home_seeker: current_user,
          callback_url: api_v1_payments_ipn_url
        )

        # Record the pending PaymentTransaction — will be updated by IPN
        escrow.payment_transactions.create!(
          direction:         "collection",
          provider:          result[:provider],
          provider_channel:  escrow.country == "KE" ? "mpesa" : "mobile_money_ug",
          provider_reference: result[:provider_reference],
          status:            "pending",
          amount_cents:      escrow.amount_cents
        )

        render json: {
          status:            "pending",
          provider_reference: result[:provider_reference],
          message:           "Payment initiated — awaiting confirmation"
        }
      rescue PaymentGatewayAdapter => e
        render json: { error: e.message }, status: :unprocessable_entity
      rescue JengaClient::JengaError => e
        Rails.logger.error "[PaymentsController#create] JengaError: #{e.message}"
        render json: { error: "Payment initiation failed — please try again" }, status: :service_unavailable
      end

      # POST /api/v1/payments/ipn
      #
      # Jenga Complete Callback Response for collection (STK push / MoMo collection).
      # On SUCCESS: fund the escrow and write the debit/credit ledger pair.
      # On failure: mark the PaymentTransaction failed.
      # Always responds 200 { status: "received" } so Jenga stops retrying.
      def ipn
        reference        = extract_collection_reference
        payment_transaction = PaymentTransaction.find_by(provider_reference: reference)

        unless payment_transaction
          Rails.logger.warn "[PaymentsController#ipn] No PaymentTransaction for reference=#{reference}"
          return render json: { status: "received" }
        end

        escrow = payment_transaction.escrow_transaction

        # Idempotency guard — skip if already processed
        unless payment_transaction.status == "pending"
          return render json: { status: "received" }
        end

        success = ipn_collection_success?

        ActiveRecord::Base.transaction do
          if success
            payment_transaction.update!(status: "success", raw_payload: safe_payload)
            # fund! writes the ledger pair internally via post_pair!
            escrow.fund!(provider_reference: reference, payload: safe_payload)
          else
            payment_transaction.update!(status: "failed", raw_payload: safe_payload)
          end
        end

        render json: { status: "received" }
      rescue => e
        Rails.logger.error "[PaymentsController#ipn] Error: #{e.class} — #{e.message}"
        # Still respond 200 to prevent infinite Jenga retries; investigate via logs
        render json: { status: "received" }
      end

      # POST /api/v1/payouts/ipn
      #
      # Jenga Send Money callback for agent payouts.
      # On success: write debit agent_payable / credit cash_out and mark withdrawal paid.
      # On failure: mark withdrawal failed (no ledger entries — agent can safely retry).
      # Always responds 200 { status: "received" }.
      def payout_ipn
        reference           = extract_payout_reference
        payment_transaction = PaymentTransaction.find_by(provider_reference: reference)

        unless payment_transaction
          Rails.logger.warn "[PaymentsController#payout_ipn] No PaymentTransaction for reference=#{reference}"
          return render json: { status: "received" }
        end

        withdrawal = Withdrawal.find_by(payment_transaction: payment_transaction)

        unless withdrawal
          Rails.logger.warn "[PaymentsController#payout_ipn] No Withdrawal for payment_transaction ##{payment_transaction.id}"
          return render json: { status: "received" }
        end

        # Idempotency guard
        unless withdrawal.processing?
          return render json: { status: "received" }
        end

        ActiveRecord::Base.transaction do
          if ipn_payout_success?
            payment_transaction.update!(status: "success", raw_payload: safe_payload)
            withdrawal.mark_paid!
          else
            payment_transaction.update!(status: "failed", raw_payload: safe_payload)
            withdrawal.mark_failed!
          end
        end

        render json: { status: "received" }
      rescue => e
        Rails.logger.error "[PaymentsController#payout_ipn] Error: #{e.class} — #{e.message}"
        render json: { status: "received" }
      end

      private

      # Extract the provider_reference from the collection IPN payload.
      # Jenga may deliver the reference under several keys depending on the endpoint.
      def extract_collection_reference
        params.dig(:transaction, :reference) ||
          params[:transactionReference]       ||
          params[:Reference]                  ||
          params[:paymentReference]
      end

      # Extract the provider_reference from the payout IPN payload.
      def extract_payout_reference
        params.dig(:data, :transReference) ||
          params.dig(:transfer, :reference) ||
          params[:reference]                ||
          params[:transactionReference]
      end

      # Determine if a collection IPN signals success.
      # Confirm the exact field against a real Jenga sandbox callback before go-live.
      def ipn_collection_success?
        params.dig(:transaction, :status)&.upcase == "SUCCESS" ||
          params[:status]&.upcase == "SUCCESS"
      end

      # Determine if a payout IPN signals success.
      # Jenga Send Money success is indicated by ResponseCode "0".
      # Confirm against a real sandbox payout callback — UAT may differ.
      def ipn_payout_success?
        params.dig(:data, :ResponseCode) == "0" ||
          params.dig(:data, :status)&.upcase == "SUCCESS" ||
          params[:status]&.upcase == "SUCCESS"
      end

      # Safe subset of params for storing in raw_payload (jsonb).
      def safe_payload
        params.except(:controller, :action, :format).to_unsafe_h
      end
    end
  end
end
