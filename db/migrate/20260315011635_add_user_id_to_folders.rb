class AddUserIdToFolders < ActiveRecord::Migration[8.1]
  def change
    add_reference :folders, :user, foreign_key: true

    remove_index :folders, :name
    add_index :folders, [ :user_id, :name ], unique: true
  end
end
