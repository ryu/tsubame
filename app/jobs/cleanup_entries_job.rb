class CleanupEntriesJob < ApplicationJob
  queue_as :default

  def perform
    count = Entry.where("read_at < ?", 90.days.ago).where(pinned: false).delete_all
    Rails.logger.info("CleanupEntriesJob: deleted #{count} old read entries")
  end
end
