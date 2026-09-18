# frozen_string_literal: true

module Api
  module V1
    # Handles Jenga API payment lifecycle:
    #   POST /api/v1/escrow_transactions/:escrow_transaction_id/pay  — initiate collection
    #   POST /api/v1/payments/jenga_ipn                              — unified Jenga IPN callback
    #
    # Jenga allows only ONE registered IPN URL per environment on JengaHQ.
    # Both collection notifications (M-Pesa STK push) and payout notifications
    # (Send Money) are received at /api/v1/payments/jenga_ipn and dispatched
    # based on the reference prefix:
    #   - "OR-..." or "PR-..." -> collection (home seeker funding escrow)
    #   - "WD-..."             -> payout (agent withdrawal payout)
    #
    # Jenga authenticates each IPN POST with HTTP Basic Auth using credentials
    # chosen during IPN registration on JengaHQ.
    # IPN endpoints skip CSRF (server-to-server callbacks) and always respond
    # with { status: "received" } so Jenga acknowledges receipt and stops retrying.
    class PaymentsController < ApplicationController
      # IPN callbacks are server-to-server POSTs from Jenga — skip CSRF.
      protect_from_forgery with: :null_session, only: [:ipn, :payout_ipn]

      # Verify HTTP Basic Auth sent by Jenga on every callback.
      before_action :verify_ipn_auth!, only: [:ipn, :payout_ipn]

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
          callback_url: api_v1_jenga_ipn_url
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

      # POST /api/v1/payments/jenga_ipn
      # (also aliased from /api/v1/payments/ipn and /api/v1/payouts/ipn for backwards compatibility)
      #
      # Unified IPN endpoint for both collection and payout callbacks.
      # Dispatches on the reference prefix:
      #   OR- / PR- -> collection (home seeker funding escrow)
      #   WD-       -> payout (agent withdrawal payout)
      # Always responds 200 { status: "received" } so Jenga stops retrying.
      def ipn
        reference = callback_reference

        case reference
        when /\AOR-|\APR-/
          confirm_collection!(reference)
        when /\AWD-/
          confirm_payout!(reference)
        else
          Rails.logger.warn "[PaymentsController#ipn] Jenga IPN with unrecognized reference: #{reference.inspect}"
        end

        render json: { status: "received" }
      rescue => e
        Rails.logger.error "[PaymentsController#ipn] Error: #{e.class} — #{e.message}"
        render json: { status: "received" }
      end
      alias_method :payout_ipn, :ipn

      private

      def confirm_collection!(reference)
        payment_transaction = PaymentTransaction.find_by(provider_reference: reference)
        unless payment_transaction
          Rails.logger.warn "[PaymentsController#ipn] No PaymentTransaction for reference=#{reference}"
          return
        end

        escrow = payment_transaction.escrow_transaction
        return unless payment_transaction.status == "pending" # idempotent

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

        # Push the live status update to the browser tab that initiated this STK push.
        # The PaymentAttempt links back via provider_reference.
        broadcast_stk_status!(reference, success: success)
      end

      def confirm_payout!(reference)
        payment_transaction = PaymentTransaction.find_by(provider_reference: reference)
        unless payment_transaction
          Rails.logger.warn "[PaymentsController#ipn] No PaymentTransaction for reference=#{reference}"
          return
        end

        withdrawal = payment_transaction.withdrawal || Withdrawal.find_by(payment_transaction: payment_transaction)
        unless withdrawal
          Rails.logger.warn "[PaymentsController#ipn] No Withdrawal for payment_transaction ##{payment_transaction.id}"
          return
        end

        return unless withdrawal.processing? # idempotent

        success = ipn_payout_success?
        ActiveRecord::Base.transaction do
          if success
            payment_transaction.update!(status: "success", raw_payload: safe_payload)
            withdrawal.mark_paid!
          else
            payment_transaction.update!(status: "failed", raw_payload: safe_payload)
            withdrawal.mark_failed!
          end
        end
      end

      # Looks up the PaymentAttempt for this provider_reference, updates its
      # stk_status, and broadcasts a Turbo Stream replace to the open browser tab.
      def broadcast_stk_status!(reference, success:)
        payment_attempt = PaymentAttempt.find_by(provider_reference: reference)
        return unless payment_attempt

        new_stk_status = success ? 'completed' : 'failed'
        new_outcome    = success ? 'success' : 'failed'
        payment_attempt.update!(stk_status: new_stk_status, outcome: new_outcome)

        Turbo::StreamsChannel.broadcast_replace_to(
          payment_attempt,
          target: "payment_status",
          partial: "payment_attempts/status",
          locals: { payment: payment_attempt }
        )
      rescue => e
        # Non-fatal — the reconcile job will clean up if broadcast fails
        Rails.logger.error "[PaymentsController#broadcast_stk_status!] #{e.class}: #{e.message}"
      end

      # Confirms this POST genuinely came from Jenga, using HTTP Basic Auth
      # with credentials configured when creating the IPN entry in JengaHQ.
      # Bypasses auth check in non-production if JENGA_IPN_USERNAME is not set.
      def verify_ipn_auth!
        config = Rails.application.config.jenga
        return true if config[:ipn_username].blank? && !Rails.env.production?

        authenticate_or_request_with_http_basic do |username, password|
          ActiveSupport::SecurityUtils.secure_compare(username.to_s, config[:ipn_username].to_s) &&
            ActiveSupport::SecurityUtils.secure_compare(password.to_s, config[:ipn_password].to_s)
        end
      end

      # Extract the provider_reference from the IPN payload.
      # Jenga may deliver references under several keys across endpoints.
      def callback_reference
        (params.dig(:transaction, :reference) ||
          params[:transactionReference]       ||
          params[:Reference]                  ||
          params.dig(:data, :transReference)  ||
          params.dig(:transfer, :reference)   ||
          params[:reference]                  ||
          params[:paymentReference]).to_s
      end

      # Determine if a collection IPN signals success.
      def ipn_collection_success?
        params.dig(:transaction, :status)&.upcase == "SUCCESS" ||
          params[:status]&.upcase == "SUCCESS"
      end

      # Determine if a payout IPN signals success.
      # Jenga Send Money success is indicated by ResponseCode "0".
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
