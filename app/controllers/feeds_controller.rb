class FeedsController < ApplicationController
  def index
    @feeds = Feed.order(:title)
  end

  def new
    @feed = Feed.new
  end

  def create
    raw_url = feed_url

    if raw_url.blank?
      @feed = Feed.new
      @feed.errors.add(:url, :blank)
      return render :new, status: :unprocessable_entity
    end

    result  = discover_feed(raw_url)

    if result[:content_type] == :feed
      return create_and_redirect(raw_url)
    end

    feed_urls = Array(result[:feed_urls])

    case feed_urls.length
    when 0
      create_and_redirect(raw_url)
    when 1
      create_and_redirect(feed_urls.first)
    when (2..)
      @feed_candidates = feed_urls
      @original_url = raw_url
      render :select_feed, status: :ok
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
    if @feed.update(feed_params)
      redirect_to feeds_path, notice: "フィードを更新しました。"
    else
      render :edit, status: :unprocessable_entity
    end
  end

  def destroy
    Feed.find(params[:id]).destroy
    redirect_to feeds_path, notice: "フィードを削除しました。"
  end

  private

  def feed_url
    params.require(:feed).permit(:url)[:url].to_s.strip
  end

  def feed_params
    params.require(:feed).permit(:title, :fetch_interval_minutes, :rate)
  end

  def discover_feed(url)
    Feed.new.discover_from(url)
  rescue Feed::SsrfError
    raise  # 呼び出し元の create アクションで処理する
  rescue StandardError => e
    Rails.logger.warn("Feed autodiscovery failed for #{url}: #{e.message}")
    { feed_urls: [], content_type: :unknown }
  end

  def create_and_redirect(url)
    @feed = Feed.subscribe(url)

    if @feed.save
      redirect_to feeds_path, notice: "フィードを追加しました。"
    else
      render :new, status: :unprocessable_entity
    end
  end
end
