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

ActiveRecord::Schema[8.1].define(version: 2026_05_13_114004) do
  create_table "bans", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.datetime "expires_at"
    t.string "ip_address", null: false
    t.string "reason"
    t.datetime "updated_at", null: false
    t.string "uuid", null: false
    t.index ["ip_address"], name: "index_bans_on_ip_address"
    t.index ["uuid"], name: "index_bans_on_uuid", unique: true
  end

  create_table "batch_uploads", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.integer "failed_files", default: 0
    t.integer "processed_files", default: 0
    t.integer "total_files", default: 0
    t.datetime "updated_at", null: false
    t.string "uploaded_by"
    t.string "uuid", null: false
    t.index ["uuid"], name: "index_batch_uploads_on_uuid", unique: true
  end

  create_table "stamp_time_logs", force: :cascade do |t|
    t.string "changed_by"
    t.datetime "created_at", null: false
    t.integer "new_seconds", null: false
    t.integer "previous_seconds", null: false
    t.integer "stamp_id", null: false
    t.datetime "updated_at", null: false
    t.string "uuid", null: false
    t.index ["stamp_id"], name: "index_stamp_time_logs_on_stamp_id"
    t.index ["uuid"], name: "index_stamp_time_logs_on_uuid", unique: true
  end

  create_table "stamps", force: :cascade do |t|
    t.integer "annotated_seconds"
    t.string "batch_id"
    t.string "category"
    t.text "category_notes"
    t.string "colorspace"
    t.datetime "created_at", null: false
    t.float "dpi"
    t.integer "estimated_seconds", default: 0
    t.string "extension", null: false
    t.string "filename", null: false
    t.boolean "has_spots", default: false
    t.integer "height_px"
    t.string "icc_profile"
    t.json "metadata", default: {}
    t.string "mime_type", null: false
    t.string "original_file"
    t.string "overlay_file"
    t.string "preview_file"
    t.string "status", default: "pending", null: false
    t.datetime "updated_at", null: false
    t.string "uuid", null: false
    t.integer "width_px"
    t.index ["status"], name: "index_stamps_on_status"
    t.index ["uuid"], name: "index_stamps_on_uuid", unique: true
  end

  add_foreign_key "stamp_time_logs", "stamps"
end
