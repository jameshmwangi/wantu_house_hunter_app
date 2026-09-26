class AddUniqueProcessingPaymentAttemptIndex < ActiveRecord::Migration[7.0]
  def up
    # Clean up existing duplicate 'processing' attempts from previous test runs
    # Keep the latest processing attempt per viewing_appointment and mark older duplicates as failed
    execute <<-SQL
      UPDATE payment_attempts
      SET stk_status = 'failed', outcome = 'failed'
      WHERE stk_status = 'processing'
        AND id NOT IN (
          SELECT MAX(id)
          FROM payment_attempts
          WHERE stk_status = 'processing'
          GROUP BY viewing_appointment_id
        );
    SQL

    add_index :payment_attempts, :viewing_appointment_id,
              unique: true,
              where: "stk_status = 'processing'",
              name: "index_one_processing_attempt_per_appointment"
  end

  def down
    remove_index :payment_attempts, name: "index_one_processing_attempt_per_appointment"
  end
end
