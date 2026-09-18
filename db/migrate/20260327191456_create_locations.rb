class CreateLocations < ActiveRecord::Migration[7.0]
  def change
    create_table :locations do |t|
      t.string :area_name, null: false
      t.string :sub_county
      t.string :county, null: false
      t.string :country, null: false, default: 'Kenya'

      t.timestamps
    end
  end
end
