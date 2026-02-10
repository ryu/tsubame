class CreateEntries < ActiveRecord::Migration[8.1]
  def change
    create_table :entries do |t|
      t.references :feed, null: false, foreign_key: true
      t.string :guid, null: false
      t.string :title
      t.string :url
      t.string :author
      t.text :body
      t.datetime :published_at
      t.datetime :read_at
      t.boolean :pinned, null: false, default: false

      t.timestamps
    end

    add_index :entries, [ :feed_id, :guid ], unique: true
    add_index :entries, :read_at
    add_index :entries, :pinned
    add_index :entries, :published_at
  end
end
