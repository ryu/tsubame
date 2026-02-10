class CreateFeeds < ActiveRecord::Migration[8.1]
  def change
    create_table :feeds do |t|
      t.string :url, null: false
      t.string :title
      t.string :site_url
      t.text :description
      t.datetime :last_fetched_at
      t.datetime :next_fetch_at
      t.integer :status, null: false, default: 0
      t.text :error_message
      t.string :etag
      t.string :last_modified

      t.timestamps
    end

    add_index :feeds, :url, unique: true
    add_index :feeds, :next_fetch_at
  end
end
