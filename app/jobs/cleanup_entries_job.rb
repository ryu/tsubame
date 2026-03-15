class CleanupEntriesJob < ApplicationJob
  queue_as :default

  def perform
    cutoff = 90.days.ago
    # Find entries older than 90 days
    old_entries = Entry.where("entries.created_at < ?", cutoff)

    # Exclude entries pinned by any user
    pinned_entry_ids = UserEntryState.where(pinned: true).select(:entry_id)
    candidates = old_entries.where.not(id: pinned_entry_ids)

    count = candidates.delete_all
    Rails.logger.info("CleanupEntriesJob: deleted #{count} old entries")
  end
end
