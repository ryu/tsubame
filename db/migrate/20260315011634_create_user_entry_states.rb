class CreateUserEntryStates < ActiveRecord::Migration[8.1]
  def change
    create_table :user_entry_states do |t|
      t.references :user, null: false, foreign_key: true
      t.references :entry, null: false, foreign_key: true
      t.datetime :read_at
      t.boolean :pinned, default: false, null: false

      t.timestamps
    end

    add_index :user_entry_states, [ :user_id, :entry_id ], unique: true
    add_index :user_entry_states, [ :user_id, :pinned ]
    add_index :user_entry_states, [ :user_id, :read_at ]
  end
end
