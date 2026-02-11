class FetchFeedJob < ApplicationJob
  queue_as :default

  def perform(feed_id)
    Feed.find_by(id: feed_id)&.fetch
  end
end
