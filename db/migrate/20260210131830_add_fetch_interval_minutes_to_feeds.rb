class AddFetchIntervalMinutesToFeeds < ActiveRecord::Migration[8.1]
  def change
    add_column :feeds, :fetch_interval_minutes, :integer, null: false, default: 10
  end
end
