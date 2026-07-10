class AddFeedIdPublishedAtIndexToEntries < ActiveRecord::Migration[8.1]
  def change
    add_index :entries, [ :feed_id, :published_at ]
    remove_index :entries, :feed_id
  end
end
