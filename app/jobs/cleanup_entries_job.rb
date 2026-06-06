class CleanupEntriesJob < ApplicationJob
  queue_as :default

  RETENTION = 90.days
  BATCH_SIZE = 1000

  # Delete entries older than RETENTION in batches. Batching keeps each DELETE small so
  # it never holds a long SQLite write lock. The job is naturally restart-safe: deleted
  # rows drop out of `deletable_entries`, so re-running after an interruption just
  # continues with whatever old entries remain.
  def perform
    deleted = 0

    loop do
      ids = deletable_entries.limit(BATCH_SIZE).pluck(:id)
      break if ids.empty?

      deleted += Entry.where(id: ids).delete_all
    end

    Rails.logger.info("CleanupEntriesJob: deleted #{deleted} old entries")
  end

  private

  def deletable_entries
    pinned_entry_ids = UserEntryState.where(pinned: true).select(:entry_id)
    Entry.where("entries.created_at < ?", RETENTION.ago).where.not(id: pinned_entry_ids)
  end
end
