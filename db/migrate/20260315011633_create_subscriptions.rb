class CreateSubscriptions < ActiveRecord::Migration[8.1]
  def change
    create_table :subscriptions do |t|
      t.references :user, null: false, foreign_key: true
      t.references :feed, null: false, foreign_key: true
      t.references :folder, foreign_key: true
      t.string :title
      t.integer :rate, default: 0, null: false

      t.timestamps
    end

    add_index :subscriptions, [ :user_id, :feed_id ], unique: true
  end
end
