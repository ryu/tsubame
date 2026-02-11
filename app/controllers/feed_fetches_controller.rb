class FeedFetchesController < ApplicationController
  def create
    @feed = Feed.find(params[:feed_id])
    FetchFeedJob.perform_now(@feed.id)
    @feed.reload
    redirect_to feeds_path, notice: "「#{@feed.title || @feed.url}」をフェッチしました。"
  rescue => e
    redirect_to feeds_path, alert: "フェッチに失敗しました。"
  end
end
