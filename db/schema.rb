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

ActiveRecord::Schema[8.0].define(version: 2026_03_01_130000) do
  create_table "collection_progress_snapshots", force: :cascade do |t|
    t.string "character_name", null: false
    t.string "locale", null: false
    t.date "captured_on", null: false
    t.integer "character_idx", null: false
    t.integer "total_collections", default: 0, null: false
    t.integer "completed_collections", default: 0, null: false
    t.integer "near_count", default: 0, null: false
    t.integer "mid_count", default: 0, null: false
    t.integer "low_count", default: 0, null: false
    t.integer "below_one_count", default: 0, null: false
    t.decimal "completion_rate", precision: 6, scale: 2, default: "0.0", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.json "collections_payload", default: [], null: false
    t.index ["character_idx", "locale", "captured_on"], name: "index_collection_progress_snapshots_unique_per_day", unique: true
    t.index ["character_idx", "locale", "created_at"], name: "index_collection_progress_snapshots_history_lookup"
  end
end
