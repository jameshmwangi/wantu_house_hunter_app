class AddStkFieldsToPaymentAttempts < ActiveRecord::Migration[7.0]
  def change
    add_column :payment_attempts, :stk_status, :string, default: "pending", null: false
    add_column :payment_attempts, :provider_reference, :string

    add_index :payment_attempts, :provider_reference
    add_index :payment_attempts, :stk_status
  end
end
