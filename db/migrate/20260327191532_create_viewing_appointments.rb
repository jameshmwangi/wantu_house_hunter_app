class CreateViewingAppointments < ActiveRecord::Migration[7.0]
  def change
    create_table :viewing_appointments do |t|
      t.references :listing, null: false, foreign_key: true
      t.references :home_seeker, null: false, foreign_key: { to_table: :users }
      t.references :agent, null: false, foreign_key: { to_table: :users }
      t.datetime :scheduled_at, null: false
      t.integer :fee_amount, null: false, default: 0
      t.string :fee_status, null: false, default: 'unpaid'
      t.string :status, null: false, default: 'pending'

      t.timestamps
    end
  end
end
