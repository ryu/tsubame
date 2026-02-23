class AddRateToFeeds < ActiveRecord::Migration[8.1]
  def change
    add_column :feeds, :rate, :integer, null: false, default: 0
  end
end
