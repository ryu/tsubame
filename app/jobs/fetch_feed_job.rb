class FetchFeedJob < ApplicationJob
  queue_as :default

  limits_concurrency key: ->(feed_id) { feed_id }

  def perform(feed_id)
    Feed.find_by(id: feed_id)&.fetch
  end
end
