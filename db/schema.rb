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

ActiveRecord::Schema[8.1].define(version: 2026_04_09_120502) do
  create_table "admins", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.integer "user_id", null: false
    t.index ["user_id"], name: "index_admins_on_user_id", unique: true
  end

  create_table "entries", force: :cascade do |t|
    t.string "author"
    t.text "body"
    t.string "content_url"
    t.datetime "created_at", null: false
    t.integer "feed_id", null: false
    t.string "guid", null: false
    t.datetime "published_at"
    t.string "title"
    t.datetime "updated_at", null: false
    t.string "url"
    t.index ["content_url"], name: "index_entries_on_content_url"
    t.index ["feed_id", "guid"], name: "index_entries_on_feed_id_and_guid", unique: true
    t.index ["feed_id"], name: "index_entries_on_feed_id"
    t.index ["published_at"], name: "index_entries_on_published_at"
  end

  create_table "feeds", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.text "description"
    t.text "error_message"
    t.string "etag"
    t.integer "fetch_interval_minutes", default: 10, null: false
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

  create_table "folders", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.string "name", null: false
    t.datetime "updated_at", null: false
    t.integer "user_id", null: false
    t.index ["user_id", "name"], name: "index_folders_on_user_id_and_name", unique: true
    t.index ["user_id"], name: "index_folders_on_user_id"
  end

  create_table "sessions", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.string "ip_address"
    t.datetime "updated_at", null: false
    t.string "user_agent"
    t.integer "user_id", null: false
    t.index ["user_id"], name: "index_sessions_on_user_id"
  end

  create_table "subscriptions", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.integer "feed_id", null: false
    t.integer "folder_id"
    t.integer "rate", default: 0, null: false
    t.string "title"
    t.datetime "updated_at", null: false
    t.integer "user_id", null: false
    t.index ["feed_id"], name: "index_subscriptions_on_feed_id"
    t.index ["folder_id"], name: "index_subscriptions_on_folder_id"
    t.index ["user_id", "feed_id"], name: "index_subscriptions_on_user_id_and_feed_id", unique: true
    t.index ["user_id"], name: "index_subscriptions_on_user_id"
  end

  create_table "user_entry_states", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.integer "entry_id", null: false
    t.boolean "pinned", default: false, null: false
    t.datetime "read_at"
    t.datetime "updated_at", null: false
    t.integer "user_id", null: false
    t.index ["entry_id"], name: "index_user_entry_states_on_entry_id"
    t.index ["user_id", "entry_id"], name: "index_user_entry_states_on_user_id_and_entry_id", unique: true
    t.index ["user_id", "pinned"], name: "index_user_entry_states_on_user_id_and_pinned"
    t.index ["user_id", "read_at"], name: "index_user_entry_states_on_user_id_and_read_at"
    t.index ["user_id"], name: "index_user_entry_states_on_user_id"
  end

  create_table "users", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.string "email_address", null: false
    t.string "password_digest", null: false
    t.datetime "updated_at", null: false
    t.index ["email_address"], name: "index_users_on_email_address", unique: true
  end

  add_foreign_key "admins", "users"
  add_foreign_key "entries", "feeds"
  add_foreign_key "folders", "users"
  add_foreign_key "sessions", "users"
  add_foreign_key "subscriptions", "feeds"
  add_foreign_key "subscriptions", "folders"
  add_foreign_key "subscriptions", "users"
  add_foreign_key "user_entry_states", "entries"
  add_foreign_key "user_entry_states", "users"
end
