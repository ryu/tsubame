class MigrateSingleUserDataToMultiUser < ActiveRecord::Migration[8.1]
  def up
    user = exec_query("SELECT id FROM users ORDER BY id LIMIT 1").first
    return unless user

    user_id = user["id"]

    execute "UPDATE folders SET user_id = #{user_id}"

    execute <<~SQL
      INSERT INTO subscriptions (user_id, feed_id, folder_id, rate, created_at, updated_at)
      SELECT #{user_id}, id, folder_id, rate, created_at, updated_at
      FROM feeds
    SQL

    execute <<~SQL
      INSERT INTO user_entry_states (user_id, entry_id, read_at, pinned, created_at, updated_at)
      SELECT #{user_id}, id, read_at, pinned, created_at, updated_at
      FROM entries
      WHERE read_at IS NOT NULL OR pinned = 1
    SQL
  end

  def down
    execute "DELETE FROM user_entry_states"
    execute "DELETE FROM subscriptions"
    execute "UPDATE folders SET user_id = NULL"
  end
end
