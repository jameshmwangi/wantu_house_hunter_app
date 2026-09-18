# frozen_string_literal: true

# Polls Jenga for PaymentTransactions that have been stuck in "pending" status
# for more than STALE_THRESHOLD, applies the correct ledger outcome, and
# resolves the associated EscrowTransaction or Withdrawal.
#
# This guards against missed IPN callbacks — Jenga docs note that callbacks can
# occasionally be missed, so a reconciliation loop is necessary for production.
#
# Scheduled via Sidekiq cron (config/sidekiq.yml) — runs every 5 minutes.
# Also safe to enqueue ad-hoc: ReconcilePendingPaymentsJob.perform_later
#
# Design doc reference: §3 (Reconciliation)
class ReconcilePendingPaymentsJob < ApplicationJob
  queue_as :reconciliation

  STALE_THRESHOLD = 10.minutes

  def perform
    stale_transactions.find_each do |pt|
      reconcile(pt)
    rescue => e
      Rails.logger.error "[ReconcilePendingPaymentsJob] Error on PaymentTransaction ##{pt.id}: #{e.class} — #{e.message}"
      # Continue to next — don't let one failure block the rest
    end
  end

  private

  def stale_transactions
    PaymentTransaction.where(status: "pending")
                      .where("created_at < ?", STALE_THRESHOLD.ago)
  end

  def reconcile(payment_transaction)
    adapter      = PaymentGatewayAdapter.new
    escrow       = payment_transaction.escrow_transaction
    country_code = escrow&.country || "KE"

    result = adapter.verify_transaction(
      payment_transaction.provider_reference,
      country_code: country_code
    )

    # Normalise the result status across Jenga response shapes
    status = (result.dig("status") || result.dig(:status) || "").upcase

    case payment_transaction.direction
    when "collection"
      reconcile_collection(payment_transaction, escrow, status)
    when "payout"
      reconcile_payout(payment_transaction, status)
    end
  end

  def reconcile_collection(payment_transaction, escrow, status)
    return if escrow.nil?

    ActiveRecord::Base.transaction do
      case status
      when "SUCCESS"
        payment_transaction.update!(status: "success")
        escrow.fund!(provider_reference: payment_transaction.provider_reference) unless escrow.funded? || escrow.released?
        Rails.logger.info "[ReconcilePendingPaymentsJob] Funded escrow ##{escrow.id} via reconciliation"
      when "FAILED", "CANCELLED"
        payment_transaction.update!(status: "failed")
        Rails.logger.info "[ReconcilePendingPaymentsJob] Marked collection ##{payment_transaction.id} failed via reconciliation"
      else
        Rails.logger.info "[ReconcilePendingPaymentsJob] Collection ##{payment_transaction.id} still pending (status=#{status})"
      end
    end
  end

  def reconcile_payout(payment_transaction, status)
    withdrawal = Withdrawal.find_by(payment_transaction: payment_transaction)
    return if withdrawal.nil?

    ActiveRecord::Base.transaction do
      case status
      when "SUCCESS"
        payment_transaction.update!(status: "success")
        withdrawal.mark_paid! if withdrawal.processing?
        Rails.logger.info "[ReconcilePendingPaymentsJob] Marked withdrawal ##{withdrawal.id} paid via reconciliation"
      when "FAILED", "CANCELLED"
        payment_transaction.update!(status: "failed")
        withdrawal.mark_failed! if withdrawal.processing?
        Rails.logger.info "[ReconcilePendingPaymentsJob] Marked withdrawal ##{withdrawal.id} failed via reconciliation"
      else
        Rails.logger.info "[ReconcilePendingPaymentsJob] Payout ##{payment_transaction.id} still pending (status=#{status})"
      end
    end
  end
end
