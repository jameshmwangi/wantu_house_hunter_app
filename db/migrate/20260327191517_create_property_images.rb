class CreatePropertyImages < ActiveRecord::Migration[7.0]
  def change
    create_table :property_images do |t|
      t.references :listing, null: false, foreign_key: true
      t.string :image_url

      t.timestamps
    end
  end
end
