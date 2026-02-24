class FeedsController < ApplicationController
  def index
    @feeds = Feed.order(:title)
  end

  def new
    @feed = Feed.new
    @folders = Folder.order(:name)
  end

  def create
    raw_url = feed_url
    folder_id = params.dig(:feed, :folder_id).to_i.nonzero?

    if raw_url.blank?
      @feed = Feed.new
      @feed.errors.add(:url, :blank)
      @folders = Folder.order(:name)
      return render :new, status: :unprocessable_entity
    end

    result  = discover_feed(raw_url)

    if result[:content_type] == :feed
      return create_and_redirect(raw_url, folder_id)
    end

    feed_urls = Array(result[:feed_urls])

    case feed_urls.length
    when 0
      create_and_redirect(raw_url, folder_id)
    when 1
      create_and_redirect(feed_urls.first, folder_id)
    when (2..)
      @feed_candidates = feed_urls
      @original_url = raw_url
      @folder_id = folder_id
      render :select_feed, status: :ok
    end
  rescue Feed::SsrfError
    @feed = Feed.new(url: raw_url)
    @feed.errors.add(:url, "cannot point to private network")
    @folders = Folder.order(:name)
    render :new, status: :unprocessable_entity
  end

  def edit
    @feed = Feed.find(params[:id])
    @folders = Folder.order(:name)
  end

  def update
    @feed = Feed.find(params[:id])
    if @feed.update(feed_params)
      redirect_to feeds_path, notice: "フィードを更新しました。"
    else
      @folders = Folder.order(:name)
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
    params.require(:feed).permit(:title, :fetch_interval_minutes, :rate, :folder_id)
  end

  def discover_feed(url)
    Feed.new.discover_from(url)
  rescue Feed::SsrfError
    raise  # 呼び出し元の create アクションで処理する
  rescue StandardError => e
    Rails.logger.warn("Feed autodiscovery failed for #{url}: #{e.message}")
    { feed_urls: [], content_type: :unknown }
  end

  def create_and_redirect(url, folder_id = nil)
    @feed = Feed.subscribe(url)
    @feed.folder_id = folder_id

    if @feed.save
      redirect_to feeds_path, notice: "フィードを追加しました。"
    else
      @folders = Folder.order(:name)
      render :new, status: :unprocessable_entity
    end
  end
end
