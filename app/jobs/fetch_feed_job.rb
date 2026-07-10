class FetchFeedJob < ApplicationJob
  queue_as :default

  # キュー滞留時に FetchFeedsJob が同一フィードを二重に積んでも並行フェッチさせない
  limits_concurrency key: ->(feed_id) { feed_id }

  def perform(feed_id)
    Feed.find_by(id: feed_id)&.fetch
  end
end
