class CreatePaymentAttempts < ActiveRecord::Migration[7.0]
  def change
    create_table :payment_attempts do |t|
      t.references :viewing_appointment, null: false, foreign_key: true
      t.string :payment_method
      t.string :outcome
      t.string :payment_reference

      t.timestamps
    end
  end
end
