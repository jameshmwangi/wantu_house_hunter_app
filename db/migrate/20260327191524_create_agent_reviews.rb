class CreateAgentReviews < ActiveRecord::Migration[7.0]
  def change
    create_table :agent_reviews do |t|
      t.references :agent, null: false, foreign_key: { to_table: :users }
      t.references :author, null: false, foreign_key: { to_table: :users }
      t.integer :rating
      t.string :title
      t.text :body

      t.timestamps
    end
  end
end
