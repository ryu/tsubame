class AddFolderIdToFeeds < ActiveRecord::Migration[8.1]
  def change
    add_column :feeds, :folder_id, :integer
    add_index :feeds, :folder_id
    add_foreign_key :feeds, :folders
  end
end
