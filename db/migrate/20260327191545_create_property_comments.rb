class CreatePropertyComments < ActiveRecord::Migration[7.0]
  def change
    create_table :property_comments do |t|
      t.references :listing, null: false, foreign_key: true
      t.references :author, null: false, foreign_key: { to_table: :users }
      t.references :parent_comment, null: true, foreign_key: { to_table: :property_comments }
      t.text :body

      t.timestamps
    end
  end
end
