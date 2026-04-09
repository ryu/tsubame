namespace :entries do
  desc "Sync read states across duplicate entries (same content_url)"
  task sync_duplicate_read_states: :environment do
    User.find_each do |user|
      read_states = user.user_entry_states.where.not(read_at: nil).includes(:entry)
      synced_count = 0

      read_states.find_each do |state|
        entry = state.entry
        next if entry.content_url.blank?

        duplicate_ids = Entry.duplicates_of(entry)
          .where.not(id: user.user_entry_states.where.not(read_at: nil).select(:entry_id))
          .pluck(:id)

        next if duplicate_ids.empty?

        records = duplicate_ids.map do |entry_id|
          { user_id: user.id, entry_id: entry_id, read_at: state.read_at, created_at: state.read_at, updated_at: state.read_at }
        end
        UserEntryState.upsert_all(records, unique_by: [ :user_id, :entry_id ], update_only: [ :read_at, :updated_at ])
        synced_count += duplicate_ids.size
      end

      puts "User #{user.id}: synced #{synced_count} duplicate entries" if synced_count > 0
    end
  end
end
