# frozen_string_literal: true

module Api
  module V1
    # Handles Pesapal API 3.0 payment lifecycle.
    #
    # Routes:
    #   POST /api/v1/escrow_transactions/:escrow_transaction_id/pay — initiate collection
    #   POST /api/v1/pesapal/ipn                                    — Pesapal IPN callback
    #
    # Pesapal flow (from PHP reference in development1/PesaPal-main):
    #   1. POST #create → PesapalClient#submit_order → returns redirect_url
    #   2. Front-end loads redirect_url in iframe (user pays on Pesapal's hosted page)
    #   3. Pesapal POSTs IPN to /api/v1/pesapal/ipn with body:
    #        { "OrderTrackingId": "...", "OrderNotificationType": "IPNCHANGE",
    #          "OrderMerchantReference": "..." }
    #   4. #ipn calls GetTransactionStatus?orderTrackingId=... and updates records
    #   5. Pesapal also redirects browser (GET) to callback_url:
    #        ?OrderTrackingId=...&OrderMerchantReference=...&OrderNotificationType=CALLBACKURL
    #      That browser callback is handled by payment_attempts#callback (not this controller).
    #
    # IPN endpoint skips CSRF (server-to-server POST from Pesapal).
    # IPN must ALWAYS respond 200 with confirmation JSON — or Pesapal will keep retrying.
    class PaymentsController < ApplicationController
      # IPN is a server-to-server POST from Pesapal — skip CSRF
      protect_from_forgery with: :null_session, only: [:ipn]

      before_action :authenticate_user!, only: [:create]

      # POST /api/v1/escrow_transactions/:escrow_transaction_id/pay
      #
      # Initiates a Pesapal order. Returns redirect_url for the hosted payment page.
      # Front-end should load redirect_url in an iframe so the user completes payment.
      def create
        escrow = EscrowTransaction.find(params[:escrow_transaction_id])

        unless escrow.home_seeker_id == current_user.id
          return render json: { error: "Not authorized" }, status: :forbidden
        end

        unless escrow.pending?
          return render json: { error: "Escrow is not in a payable state" }, status: :unprocessable_entity
        end

        # Zero-amount: short-circuit — no gateway call needed
        if escrow.amount_cents.zero?
          escrow.fund!
          return render json: { status: "funded", message: "Zero-amount escrow funded immediately" }
        end

        adapter = PaymentGatewayAdapter.new
        result  = adapter.initiate_collection(
          escrow,
          home_seeker:  current_user,
          callback_url: api_v1_pesapal_callback_url
        )

        # Store order_tracking_id as provider_reference for IPN + reconciliation lookup
        escrow.payment_transactions.create!(
          direction:          "collection",
          provider:           result[:provider],
          provider_channel:   escrow.country == "KE" ? "mpesa" : "mobile_money_ug",
          provider_reference: result[:provider_reference],   # = order_tracking_id
          status:             "pending",
          amount_cents:       escrow.amount_cents
        )

        render json: {
          status:             "pending",
          order_tracking_id:  result[:provider_reference],
          merchant_reference: result[:merchant_reference],
          redirect_url:       result[:redirect_url],
          message:            "Order created — load redirect_url in an iframe to complete payment"
        }
      rescue PaymentGatewayAdapter::Error => e
        render json: { error: e.message }, status: :service_unavailable
      rescue PesapalClient::PesapalError => e
        Rails.logger.error "[PaymentsController#create] PesapalError: #{e.message}"
        render json: { error: "Payment initiation failed — please try again" }, status: :service_unavailable
      end

      # POST /api/v1/pesapal/ipn
      #
      # Pesapal server-to-server IPN callback.
      # Payload (confirmed from development1/PesaPal-main/pin.json):
      #   { "OrderTrackingId": "cb7fec53-...", "OrderNotificationType": "IPNCHANGE",
      #     "OrderMerchantReference": "607821822..." }
      #
      # Must ALWAYS respond 200 with confirmation JSON (Pesapal retries if it doesn't):
      #   { "orderNotificationType": "IPNCHANGE", "orderTrackingId": "...",
      #     "orderMerchantReference": "...", "status": 200 }
      def ipn
        order_tracking_id      = params[:OrderTrackingId]      || params[:orderTrackingId]
        order_merchant_ref     = params[:OrderMerchantReference] || params[:orderMerchantReference]
        order_notification_type = params[:OrderNotificationType] || params[:orderNotificationType] || "IPNCHANGE"

        if order_tracking_id.present?
          process_pesapal_ipn!(order_tracking_id)
        else
          Rails.logger.warn "[PaymentsController#ipn] Pesapal IPN missing OrderTrackingId. Params: #{params.inspect}"
        end

        # Confirmation response Pesapal expects — always respond 200
        render json: {
          orderNotificationType:  order_notification_type,
          orderTrackingId:        order_tracking_id,
          orderMerchantReference: order_merchant_ref,
          status:                 200
        }
      rescue => e
        Rails.logger.error "[PaymentsController#ipn] #{e.class}: #{e.message}"
        # Still respond 200 with status 500 body so Pesapal knows we received but errored
        render json: {
          orderNotificationType:  "IPNCHANGE",
          orderTrackingId:        params[:OrderTrackingId],
          orderMerchantReference: params[:OrderMerchantReference],
          status:                 500
        }
      end

      # GET /api/v1/pesapal/callback
      #
      # Browser redirect-back from Pesapal after the user completes (or cancels) payment.
      # Params (from response-page.php reference):
      #   ?OrderTrackingId=...&OrderMerchantReference=...&OrderNotificationType=CALLBACKURL
      #
      # This is a browser GET — do NOT return JSON. Call GetTransactionStatus and
      # redirect to the payment_status page so the user sees the result.
      def callback
        order_tracking_id  = params[:OrderTrackingId]
        merchant_reference = params[:OrderMerchantReference]

        if order_tracking_id.blank?
          Rails.logger.warn "[PaymentsController#callback] No OrderTrackingId in callback params"
          return redirect_to root_path, alert: "Payment callback received without order tracking ID"
        end

        # Look up the PaymentAttempt by provider_reference (= order_tracking_id)
        payment_attempt = PaymentAttempt.find_by(provider_reference: order_tracking_id)

        if payment_attempt
          # If not yet resolved, call GetTransactionStatus now (browser is here, good time to check)
          if payment_attempt.stk_status == "processing"
            begin
              status_response = PesapalClient.new.get_transaction_status(order_tracking_id)
              status_code     = status_response["status_code"].to_i
              if status_code == 1
                payment_attempt.update!(stk_status: "completed", outcome: "success")
                escrow = payment_attempt.viewing_appointment.escrow_transaction
                escrow&.fund!(provider_reference: order_tracking_id, payload: safe_payload) unless escrow&.funded? || escrow&.released?
              elsif status_code.in?([2, 3])
                payment_attempt.update!(stk_status: "failed", outcome: "failed")
              end
            rescue PesapalClient::PesapalError => e
              Rails.logger.error "[PaymentsController#callback] GetTransactionStatus failed: #{e.message}"
            end
          end

          listing = payment_attempt.viewing_appointment.listing
          if payment_attempt.outcome == "success"
            redirect_to listing_path(listing), notice: t('payment_attempts.success', reference: order_tracking_id, default: "Payment received — your viewing appointment is confirmed!")
          elsif payment_attempt.outcome == "failed"
            redirect_to listing_path(listing), alert: t('payment_attempts.failure', default: "Payment failed or was cancelled. Please try again.")
          else
            redirect_to listing_path(listing), notice: t('payment_attempts.stk_initiated', default: "Payment is being processed. We will confirm your booking shortly.")
          end
        else
          Rails.logger.warn "[PaymentsController#callback] No PaymentAttempt for OrderTrackingId=#{order_tracking_id}"
          redirect_to root_path, notice: "Payment received — we will confirm your booking shortly."
        end
      end

      private

      # Called from #ipn — fetches GetTransactionStatus and updates records.
      def process_pesapal_ipn!(order_tracking_id)
        payment_transaction = PaymentTransaction.find_by(provider_reference: order_tracking_id)
        unless payment_transaction
          Rails.logger.warn "[PaymentsController#ipn] No PaymentTransaction for OrderTrackingId=#{order_tracking_id}"
          return
        end

        return unless payment_transaction.status == "pending" # idempotent

        # Call GetTransactionStatus — same pattern as response-page.php in PHP reference
        status_response = PesapalClient.new.get_transaction_status(order_tracking_id)
        status_code = status_response["status_code"].to_i

        # 0 = INVALID (not final yet), 1 = COMPLETED, 2 = FAILED, 3 = REVERSED
        return if status_code == 0 # still pending — wait for next IPN

        success = (status_code == 1)
        escrow  = payment_transaction.escrow_transaction

        ActiveRecord::Base.transaction do
          if success
            payment_transaction.update!(status: "success", raw_payload: safe_payload)
            escrow&.fund!(provider_reference: order_tracking_id, payload: safe_payload) unless escrow&.funded? || escrow&.released?
          else
            payment_transaction.update!(status: "failed", raw_payload: safe_payload)
          end
        end

        broadcast_pesapal_status!(order_tracking_id, success: success)
      rescue PesapalClient::PesapalError => e
        Rails.logger.error "[PaymentsController#ipn] GetTransactionStatus failed: #{e.message}"
      end

      # Push the live status update to any open browser tab via Turbo Streams.
      def broadcast_pesapal_status!(order_tracking_id, success:)
        payment_attempt = PaymentAttempt.find_by(provider_reference: order_tracking_id)
        return unless payment_attempt

        new_stk_status = success ? "completed" : "failed"
        new_outcome    = success ? "success"   : "failed"
        payment_attempt.update!(stk_status: new_stk_status, outcome: new_outcome)

        Turbo::StreamsChannel.broadcast_replace_to(
          payment_attempt,
          target:  "payment_status",
          partial: "payment_attempts/status",
          locals:  { payment: payment_attempt }
        )
      rescue => e
        Rails.logger.error "[PaymentsController#broadcast_pesapal_status!] #{e.class}: #{e.message}"
      end

      # Safe subset of params for storing in raw_payload (jsonb).
      def safe_payload
        params.except(:controller, :action, :format).to_unsafe_h
      end
    end
  end
end
