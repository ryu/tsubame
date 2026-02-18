class FeedsController < ApplicationController
  def index
    @feeds = Feed.all.order(:title)
  end

  def new
    @feed = Feed.new
  end

  def create
    raw_url = params.require(:feed).permit(:url)[:url].to_s.strip
    result = discover_feed(raw_url)

    case result[:content_type]
    when :feed
      save_feed(raw_url)
    else
      if result[:feed_urls].size == 1
        save_feed(result[:feed_urls].first)
      elsif result[:feed_urls].size >= 2
        @feed_candidates = result[:feed_urls]
        @original_url = raw_url
        render :select_feed, status: :ok
      else
        save_feed(raw_url)
      end
    end
  rescue Feed::SsrfError
    @feed = Feed.new(url: raw_url)
    @feed.errors.add(:url, "cannot point to private network")
    render :new, status: :unprocessable_entity
  end

  def edit
    @feed = Feed.find(params[:id])
  end

  def update
    @feed = Feed.find(params[:id])
    if @feed.update(params.require(:feed).permit(:title, :fetch_interval_minutes))
      redirect_to feeds_path, notice: "フィードを更新しました。"
    else
      render :edit, status: :unprocessable_entity
    end
  end

  def destroy
    @feed = Feed.find(params[:id])
    @feed.destroy
    redirect_to feeds_path, notice: "フィードを削除しました。"
  end

  private

  def discover_feed(url)
    Feed.new.discover_from(url)
  rescue Feed::SsrfError
    raise
  rescue StandardError => e
    Rails.logger.warn("Feed autodiscovery failed for #{url}: #{e.message}")
    { feed_urls: [], content_type: :unknown }
  end

  def save_feed(url)
    @feed = Feed.new(url: url)
    @feed.next_fetch_at = Time.current
    if @feed.save
      redirect_to feeds_path, notice: "フィードを追加しました。"
    else
      render :new, status: :unprocessable_entity
    end
  end
end
