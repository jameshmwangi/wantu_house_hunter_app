class UpdateActiveStorageBlobsToCloudflare < ActiveRecord::Migration[7.0]
  def up
    # Updates active_storage_blobs service_name from 'amazon' to 'cloudflare'
    # Run `rails storage:migrate_to_r2` first if files still need to be copied across buckets.
    execute("UPDATE active_storage_blobs SET service_name = 'cloudflare' WHERE service_name = 'amazon'")
  end

  def down
    execute("UPDATE active_storage_blobs SET service_name = 'amazon' WHERE service_name = 'cloudflare'")
  end
end
