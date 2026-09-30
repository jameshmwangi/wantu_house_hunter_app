# This file is auto-generated from the current state of the database. Instead
# of editing this file, please use the migrations feature of Active Record to
# incrementally modify your database, and then regenerate this schema definition.
#
# This file is the source Rails uses to define your schema when running `bin/rails
# db:schema:load`. When creating a new database, `bin/rails db:schema:load` tends to
# be faster and is potentially less error prone than running all of your
# migrations from scratch. Old migrations may fail to apply correctly if those
# migrations use external dependencies or application code.
#
# It's strongly recommended that you check this file into your version control system.

ActiveRecord::Schema[7.0].define(version: 2026_09_30_091500) do
  # These are extensions that must be enabled in order to support this database
  enable_extension "plpgsql"

  create_table "active_storage_attachments", force: :cascade do |t|
    t.string "name", null: false
    t.string "record_type", null: false
    t.bigint "record_id", null: false
    t.bigint "blob_id", null: false
    t.datetime "created_at", null: false
    t.index ["blob_id"], name: "index_active_storage_attachments_on_blob_id"
    t.index ["record_type", "record_id", "name", "blob_id"], name: "index_active_storage_attachments_uniqueness", unique: true
  end

  create_table "active_storage_blobs", force: :cascade do |t|
    t.string "key", null: false
    t.string "filename", null: false
    t.string "content_type"
    t.text "metadata"
    t.string "service_name", null: false
    t.bigint "byte_size", null: false
    t.string "checksum"
    t.datetime "created_at", null: false
    t.index ["key"], name: "index_active_storage_blobs_on_key", unique: true
  end

  create_table "active_storage_variant_records", force: :cascade do |t|
    t.bigint "blob_id", null: false
    t.string "variation_digest", null: false
    t.index ["blob_id", "variation_digest"], name: "index_active_storage_variant_records_uniqueness", unique: true
  end

  create_table "agent_reviews", force: :cascade do |t|
    t.bigint "agent_id", null: false
    t.bigint "author_id", null: false
    t.integer "rating"
    t.string "title"
    t.text "body"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["agent_id"], name: "index_agent_reviews_on_agent_id"
    t.index ["author_id"], name: "index_agent_reviews_on_author_id"
  end

  create_table "escrow_transactions", force: :cascade do |t|
    t.bigint "viewing_appointment_id", null: false
    t.bigint "listing_id", null: false
    t.bigint "home_seeker_id", null: false
    t.bigint "agent_id", null: false
    t.bigint "amount_cents", null: false
    t.string "currency", null: false
    t.string "country", null: false
    t.string "status", default: "pending", null: false
    t.string "confirmation_code"
    t.datetime "confirmation_code_expires_at"
    t.integer "confirmation_attempts", default: 0, null: false
    t.datetime "funded_at"
    t.datetime "released_at"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["agent_id"], name: "index_escrow_transactions_on_agent_id"
    t.index ["confirmation_code"], name: "index_escrow_transactions_on_confirmation_code"
    t.index ["home_seeker_id"], name: "index_escrow_transactions_on_home_seeker_id"
    t.index ["listing_id"], name: "index_escrow_transactions_on_listing_id"
    t.index ["viewing_appointment_id"], name: "index_escrow_transactions_on_viewing_appointment_id", unique: true
  end

  create_table "favourites", force: :cascade do |t|
    t.bigint "user_id", null: false
    t.bigint "listing_id", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["listing_id"], name: "index_favourites_on_listing_id"
    t.index ["user_id", "listing_id"], name: "index_favourites_on_user_id_and_listing_id", unique: true
    t.index ["user_id"], name: "index_favourites_on_user_id"
  end

  create_table "ledger_entries", force: :cascade do |t|
    t.bigint "escrow_transaction_id", null: false
    t.string "account", null: false
    t.string "entry_type", null: false
    t.bigint "amount_cents", null: false
    t.string "currency", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["escrow_transaction_id", "account"], name: "index_ledger_entries_on_escrow_transaction_id_and_account"
    t.index ["escrow_transaction_id"], name: "index_ledger_entries_on_escrow_transaction_id"
  end

  create_table "listings", force: :cascade do |t|
    t.bigint "user_id", null: false
    t.bigint "location_id", null: false
    t.string "title"
    t.text "description"
    t.string "need_type"
    t.string "use_case"
    t.string "room_layout"
    t.integer "price"
    t.string "price_period"
    t.string "building_name"
    t.integer "viewing_fee"
    t.string "status", default: "draft", null: false
    t.boolean "featured", default: false, null: false
    t.integer "bathrooms"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["location_id"], name: "index_listings_on_location_id"
    t.index ["user_id"], name: "index_listings_on_user_id"
  end

  create_table "locations", force: :cascade do |t|
    t.string "area_name", null: false
    t.string "sub_county"
    t.string "county", null: false
    t.string "country", default: "Kenya", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
  end

  create_table "payment_attempts", force: :cascade do |t|
    t.bigint "viewing_appointment_id", null: false
    t.string "payment_method"
    t.string "outcome"
    t.string "payment_reference"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.string "stk_status", default: "pending", null: false
    t.string "provider_reference"
    t.text "redirect_url"
    t.index ["provider_reference"], name: "index_payment_attempts_on_provider_reference"
    t.index ["stk_status"], name: "index_payment_attempts_on_stk_status"
    t.index ["viewing_appointment_id"], name: "index_one_processing_attempt_per_appointment", unique: true, where: "((stk_status)::text = 'processing'::text)"
    t.index ["viewing_appointment_id"], name: "index_payment_attempts_on_viewing_appointment_id"
  end

  create_table "payment_transactions", force: :cascade do |t|
    t.bigint "escrow_transaction_id", null: false
    t.string "direction", null: false
    t.string "provider"
    t.string "provider_channel"
    t.string "provider_reference"
    t.string "status", default: "initiated", null: false
    t.jsonb "raw_payload", default: {}, null: false
    t.bigint "amount_cents", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["escrow_transaction_id"], name: "index_payment_transactions_on_escrow_transaction_id"
    t.index ["provider_reference"], name: "index_payment_transactions_on_provider_reference", unique: true, where: "(provider_reference IS NOT NULL)"
  end

  create_table "payout_accounts", force: :cascade do |t|
    t.bigint "agent_id", null: false
    t.string "country", null: false
    t.string "kind", null: false
    t.text "details", null: false
    t.boolean "verified", default: false, null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["agent_id", "country", "kind"], name: "index_payout_accounts_on_agent_id_and_country_and_kind", unique: true
    t.index ["agent_id"], name: "index_payout_accounts_on_agent_id"
  end

  create_table "property_comments", force: :cascade do |t|
    t.bigint "listing_id", null: false
    t.bigint "author_id", null: false
    t.bigint "parent_comment_id"
    t.text "body"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["author_id"], name: "index_property_comments_on_author_id"
    t.index ["listing_id"], name: "index_property_comments_on_listing_id"
    t.index ["parent_comment_id"], name: "index_property_comments_on_parent_comment_id"
  end

  create_table "property_images", force: :cascade do |t|
    t.bigint "listing_id", null: false
    t.string "image_url"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["listing_id"], name: "index_property_images_on_listing_id"
  end

  create_table "users", force: :cascade do |t|
    t.string "email", default: "", null: false
    t.string "encrypted_password", default: "", null: false
    t.string "reset_password_token"
    t.datetime "reset_password_sent_at"
    t.datetime "remember_created_at"
    t.string "full_name", null: false
    t.string "phone_number"
    t.string "role", default: "home_seeker", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.text "bio"
    t.index ["email"], name: "index_users_on_email", unique: true
    t.index ["phone_number"], name: "index_users_on_phone_number"
    t.index ["reset_password_token"], name: "index_users_on_reset_password_token", unique: true
    t.index ["role"], name: "index_users_on_role"
  end

  create_table "viewing_appointments", force: :cascade do |t|
    t.bigint "listing_id", null: false
    t.bigint "home_seeker_id", null: false
    t.bigint "agent_id", null: false
    t.datetime "scheduled_at", null: false
    t.integer "fee_amount", default: 0, null: false
    t.string "fee_status", default: "unpaid", null: false
    t.string "status", default: "pending", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["agent_id"], name: "index_viewing_appointments_on_agent_id"
    t.index ["home_seeker_id"], name: "index_viewing_appointments_on_home_seeker_id"
    t.index ["listing_id"], name: "index_viewing_appointments_on_listing_id"
  end

  create_table "withdrawals", force: :cascade do |t|
    t.bigint "agent_id", null: false
    t.bigint "payout_account_id", null: false
    t.bigint "payment_transaction_id"
    t.bigint "amount_cents", null: false
    t.string "currency", null: false
    t.string "status", default: "requested", null: false
    t.datetime "requested_at", null: false
    t.datetime "completed_at"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["agent_id"], name: "index_withdrawals_on_agent_id"
    t.index ["payment_transaction_id"], name: "index_withdrawals_on_payment_transaction_id"
    t.index ["payout_account_id"], name: "index_withdrawals_on_payout_account_id"
  end

  add_foreign_key "active_storage_attachments", "active_storage_blobs", column: "blob_id"
  add_foreign_key "active_storage_variant_records", "active_storage_blobs", column: "blob_id"
  add_foreign_key "agent_reviews", "users", column: "agent_id"
  add_foreign_key "agent_reviews", "users", column: "author_id"
  add_foreign_key "escrow_transactions", "listings"
  add_foreign_key "escrow_transactions", "users", column: "agent_id"
  add_foreign_key "escrow_transactions", "users", column: "home_seeker_id"
  add_foreign_key "escrow_transactions", "viewing_appointments"
  add_foreign_key "favourites", "listings"
  add_foreign_key "favourites", "users"
  add_foreign_key "ledger_entries", "escrow_transactions"
  add_foreign_key "listings", "locations"
  add_foreign_key "listings", "users"
  add_foreign_key "payment_attempts", "viewing_appointments"
  add_foreign_key "payment_transactions", "escrow_transactions"
  add_foreign_key "payout_accounts", "users", column: "agent_id"
  add_foreign_key "property_comments", "listings"
  add_foreign_key "property_comments", "property_comments", column: "parent_comment_id"
  add_foreign_key "property_comments", "users", column: "author_id"
  add_foreign_key "property_images", "listings"
  add_foreign_key "viewing_appointments", "listings"
  add_foreign_key "viewing_appointments", "users", column: "agent_id"
  add_foreign_key "viewing_appointments", "users", column: "home_seeker_id"
  add_foreign_key "withdrawals", "payment_transactions"
  add_foreign_key "withdrawals", "payout_accounts"
  add_foreign_key "withdrawals", "users", column: "agent_id"
end
