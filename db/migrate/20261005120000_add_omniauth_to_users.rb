class AddOmniauthToUsers < ActiveRecord::Migration[7.0]
  def up
    add_column :users, :provider, :string, null: false, default: ""
    add_column :users, :uid,      :string, null: false, default: ""

    # Backfill existing users with unique uid so the unique index doesn't
    # reject rows that all share the same blank uid + blank provider.
    execute <<~SQL
      UPDATE users
      SET uid      = gen_random_uuid()::text,
          provider = 'email'
      WHERE uid = '' OR uid IS NULL;
    SQL

    add_index :users, [:uid, :provider], unique: true
  end

  def down
    remove_index :users, [:uid, :provider]
    remove_column :users, :uid
    remove_column :users, :provider
  end
end
