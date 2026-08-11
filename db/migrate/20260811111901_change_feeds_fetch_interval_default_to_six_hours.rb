class ChangeFeedsFetchIntervalDefaultToSixHours < ActiveRecord::Migration[8.1]
  def change
    change_column_default :feeds, :fetch_interval_minutes, from: 10, to: 360
  end
end
