class CreateListings < ActiveRecord::Migration[7.0]
  def change
    create_table :listings do |t|
      t.references :user, null: false, foreign_key: true
      t.references :location, null: false, foreign_key: true
      t.string :title
      t.text :description
      t.string :need_type
      t.string :use_case
      t.string :room_layout
      t.integer :price
      t.string :price_period
      t.string :building_name
      t.integer :viewing_fee
      t.string :status, null: false, default: 'draft'
      t.boolean :featured, null: false, default: false
      t.integer :bathrooms

      t.timestamps
    end
  end
end
