class FetchFeedsJob < ApplicationJob
  queue_as :default

  def perform
    Feed.due_for_fetch.find_each do |feed|
      FetchFeedJob.perform_later(feed.id)
    end
  end
end
