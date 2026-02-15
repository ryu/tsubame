class FeedFetchesController < ApplicationController
  def create
    @feed = Feed.find(params[:feed_id])
    @feed.fetch
    @feed.reload
    redirect_to feeds_path, notice: "「#{@feed.title || @feed.url}」をフェッチしました。"
  rescue ActiveRecord::RecordNotFound
    redirect_to feeds_path, alert: "フィードが見つかりませんでした。"
  end
end
