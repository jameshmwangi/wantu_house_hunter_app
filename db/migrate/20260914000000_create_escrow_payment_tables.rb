class CreateEscrowPaymentTables < ActiveRecord::Migration[7.0]
  def change
    create_table :escrow_transactions do |t|
      t.references :viewing_appointment, null: false, foreign_key: true, index: { unique: true }
      t.references :listing, null: false, foreign_key: true
      t.references :home_seeker, null: false, foreign_key: { to_table: :users }
      t.references :agent, null: false, foreign_key: { to_table: :users }
      t.bigint :amount_cents, null: false
      t.string :currency, null: false
      t.string :country, null: false
      t.string :status, null: false, default: "pending"
      t.string :confirmation_code
      t.datetime :confirmation_code_expires_at
      t.integer :confirmation_attempts, null: false, default: 0
      t.datetime :funded_at
      t.datetime :released_at
      t.timestamps
    end

    add_index :escrow_transactions, :confirmation_code

    create_table :ledger_entries do |t|
      t.references :escrow_transaction, null: false, foreign_key: true
      t.string :account, null: false
      t.string :entry_type, null: false
      t.bigint :amount_cents, null: false
      t.string :currency, null: false
      t.timestamps
    end
    add_index :ledger_entries, [:escrow_transaction_id, :account]

    create_table :payment_transactions do |t|
      t.references :escrow_transaction, null: false, foreign_key: true
      t.string :direction, null: false
      t.string :provider
      t.string :provider_channel
      t.string :provider_reference
      t.string :status, null: false, default: "initiated"
      t.jsonb :raw_payload, null: false, default: {}
      t.bigint :amount_cents, null: false
      t.timestamps
    end
    add_index :payment_transactions, :provider_reference, unique: true, where: "provider_reference IS NOT NULL"

    create_table :payout_accounts do |t|
      t.references :agent, null: false, foreign_key: { to_table: :users }
      t.string :country, null: false
      t.string :kind, null: false
      t.text :details, null: false
      t.boolean :verified, null: false, default: false
      t.timestamps
    end
    add_index :payout_accounts, [:agent_id, :country, :kind], unique: true

    create_table :withdrawals do |t|
      t.references :agent, null: false, foreign_key: { to_table: :users }
      t.references :payout_account, null: false, foreign_key: true
      t.references :payment_transaction, foreign_key: true
      t.bigint :amount_cents, null: false
      t.string :currency, null: false
      t.string :status, null: false, default: "requested"
      t.datetime :requested_at, null: false
      t.datetime :completed_at
      t.timestamps
    end
  end
end
