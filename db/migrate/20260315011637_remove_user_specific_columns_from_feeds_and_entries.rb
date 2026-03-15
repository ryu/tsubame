class RemoveUserSpecificColumnsFromFeedsAndEntries < ActiveRecord::Migration[8.1]
  def change
    # Make folders.user_id NOT NULL after data migration
    change_column_null :folders, :user_id, false

    remove_foreign_key :feeds, :folders
    remove_reference :feeds, :folder, index: true
    remove_column :feeds, :rate, :integer, default: 0, null: false

    remove_column :entries, :read_at, :datetime
    remove_column :entries, :pinned, :boolean, default: false, null: false
    remove_index :entries, :pinned, if_exists: true
    remove_index :entries, :read_at, if_exists: true
  end
end
