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

ActiveRecord::Schema[8.1].define(version: 2026_02_10_005736) do
  create_table "entries", force: :cascade do |t|
    t.string "author"
    t.text "body"
    t.datetime "created_at", null: false
    t.integer "feed_id", null: false
    t.string "guid", null: false
    t.boolean "pinned", default: false, null: false
    t.datetime "published_at"
    t.datetime "read_at"
    t.string "title"
    t.datetime "updated_at", null: false
    t.string "url"
    t.index ["feed_id", "guid"], name: "index_entries_on_feed_id_and_guid", unique: true
    t.index ["feed_id"], name: "index_entries_on_feed_id"
    t.index ["pinned"], name: "index_entries_on_pinned"
    t.index ["published_at"], name: "index_entries_on_published_at"
    t.index ["read_at"], name: "index_entries_on_read_at"
  end

  create_table "feeds", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.text "description"
    t.text "error_message"
    t.string "etag"
    t.datetime "last_fetched_at"
    t.string "last_modified"
    t.datetime "next_fetch_at"
    t.string "site_url"
    t.integer "status", default: 0, null: false
    t.string "title"
    t.datetime "updated_at", null: false
    t.string "url", null: false
    t.index ["next_fetch_at"], name: "index_feeds_on_next_fetch_at"
    t.index ["url"], name: "index_feeds_on_url", unique: true
  end

  create_table "sessions", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.string "ip_address"
    t.datetime "updated_at", null: false
    t.string "user_agent"
    t.integer "user_id", null: false
    t.index ["user_id"], name: "index_sessions_on_user_id"
  end

  create_table "users", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.string "email_address", null: false
    t.string "password_digest", null: false
    t.datetime "updated_at", null: false
    t.index ["email_address"], name: "index_users_on_email_address", unique: true
  end

  add_foreign_key "entries", "feeds"
  add_foreign_key "sessions", "users"
end
