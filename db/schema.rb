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

ActiveRecord::Schema[8.1].define(version: 2026_08_10_194816) do
  # These are extensions that must be enabled in order to support this database
  enable_extension "pg_catalog.plpgsql"

  create_table "active_storage_attachments", force: :cascade do |t|
    t.bigint "blob_id", null: false
    t.datetime "created_at", null: false
    t.string "name", null: false
    t.bigint "record_id", null: false
    t.string "record_type", null: false
    t.index ["blob_id"], name: "index_active_storage_attachments_on_blob_id"
    t.index ["record_type", "record_id", "name", "blob_id"], name: "index_active_storage_attachments_uniqueness", unique: true
  end

  create_table "active_storage_blobs", force: :cascade do |t|
    t.bigint "byte_size", null: false
    t.string "checksum"
    t.string "content_type"
    t.datetime "created_at", null: false
    t.string "filename", null: false
    t.string "key", null: false
    t.text "metadata"
    t.string "service_name", null: false
    t.index ["key"], name: "index_active_storage_blobs_on_key", unique: true
  end

  create_table "active_storage_variant_records", force: :cascade do |t|
    t.bigint "blob_id", null: false
    t.string "variation_digest", null: false
    t.index ["blob_id", "variation_digest"], name: "index_active_storage_variant_records_uniqueness", unique: true
  end

  create_table "photos", force: :cascade do |t|
    t.string "author"
    t.datetime "created_at", null: false
    t.string "licence"
    t.bigint "roundabout_id", null: false
    t.string "source_url"
    t.date "taken_on", null: false
    t.datetime "updated_at", null: false
    t.index ["roundabout_id", "taken_on"], name: "index_photos_on_roundabout_id_and_taken_on"
    t.index ["roundabout_id"], name: "index_photos_on_roundabout_id"
  end

  create_table "roundabouts", force: :cascade do |t|
    t.string "commune"
    t.datetime "created_at", null: false
    t.string "departement"
    t.decimal "diameter_m", precision: 6, scale: 1
    t.string "insee_code"
    t.decimal "lat", precision: 9, scale: 6, null: false
    t.decimal "lon", precision: 9, scale: 6, null: false
    t.string "name"
    t.bigint "osm_way_ids", default: [], null: false, array: true
    t.string "region"
    t.datetime "updated_at", null: false
    t.index ["diameter_m"], name: "index_roundabouts_on_diameter_m"
    t.index ["insee_code"], name: "index_roundabouts_on_insee_code"
    t.index ["lat", "lon"], name: "index_roundabouts_on_lat_and_lon"
  end

  create_table "votes", force: :cascade do |t|
    t.string "category", null: false
    t.datetime "created_at", null: false
    t.bigint "roundabout_id", null: false
    t.datetime "updated_at", null: false
    t.string "voter_token", null: false
    t.integer "year", null: false
    t.index ["category", "year"], name: "index_votes_on_category_and_year"
    t.index ["roundabout_id", "category", "year", "voter_token"], name: "index_votes_uniqueness", unique: true
    t.index ["roundabout_id"], name: "index_votes_on_roundabout_id"
  end

  add_foreign_key "active_storage_attachments", "active_storage_blobs", column: "blob_id"
  add_foreign_key "active_storage_variant_records", "active_storage_blobs", column: "blob_id"
  add_foreign_key "photos", "roundabouts"
  add_foreign_key "votes", "roundabouts"
end
