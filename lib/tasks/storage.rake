namespace :storage do
  desc "Migrate Active Storage blobs from S3 (:amazon) to Cloudflare R2 (:cloudflare) and update the database"
  task migrate_to_r2: :environment do
    source_service_name = :amazon
    target_service_name = :cloudflare

    source = ActiveStorage::Blob.services.fetch(source_service_name)
    target = ActiveStorage::Blob.services.fetch(target_service_name)

    blobs = ActiveStorage::Blob.where(service_name: source_service_name.to_s)
    total = blobs.count

    puts "Found #{total} blob(s) with service_name '#{source_service_name}' to migrate to '#{target_service_name}'."
    next if total.zero?

    success_count = 0
    skipped_count = 0
    failed_count = 0

    blobs.find_each.with_index(1) do |blob, index|
      print "[#{index}/#{total}] Blob #{blob.id} (#{blob.key})... "

      begin
        # Check if already in target R2 bucket
        if target.exist?(blob.key)
          print "already exists in R2, updating DB record... "
          skipped_count += 1
        else
          # Download from source S3 and stream to target R2
          source.open(blob.key, checksum: blob.checksum) do |tempfile|
            target.upload(
              blob.key,
              tempfile,
              checksum: blob.checksum,
              content_type: blob.content_type
            )
          end
          print "copied to R2... "
          success_count += 1
        end

        # Update service_name in database
        blob.update_columns(service_name: target_service_name.to_s)
        puts "DONE"
      rescue StandardError => e
        failed_count += 1
        puts "FAILED: #{e.message}"
      end
    end

    puts "\n=========================================="
    puts "Migration Summary:"
    puts "  Copied to R2: #{success_count}"
    puts "  Already in R2 (DB updated): #{skipped_count}"
    puts "  Failed: #{failed_count}"
    puts "=========================================="
  end

  desc "Update DB service_name from amazon to cloudflare (use if files are already synced via rclone or Super Slurper)"
  task update_db_service_name: :environment do
    count = ActiveStorage::Blob.where(service_name: "amazon").update_all(service_name: "cloudflare")
    puts "Updated #{count} ActiveStorage::Blob record(s) from 'amazon' to 'cloudflare'."
  end

  desc "Verify all cloudflare blobs exist in R2"
  task verify_r2: :environment do
    target = ActiveStorage::Blob.services.fetch(:cloudflare)
    blobs = ActiveStorage::Blob.where(service_name: "cloudflare")
    total = blobs.count
    missing = 0

    puts "Checking #{total} blob(s) in Cloudflare R2..."
    blobs.find_each.with_index(1) do |blob, index|
      unless target.exist?(blob.key)
        puts "MISSING: Blob #{blob.id} (#{blob.key} - #{blob.filename})"
        missing += 1
      end
    end

    puts "Verification complete. Missing: #{missing} / #{total}."
  end
end
