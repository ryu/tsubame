class FeedsController < ApplicationController
  def index
    @subscriptions = Current.user.subscriptions.includes(:feed).joins(:feed).merge(Feed.order(:title))
  end

  def new
    @feed = Feed.new
    @folders = Current.user.folders.order(:name)
  end

  def select
    @feed_candidates = session.delete(:feed_candidates)
    @original_url    = session.delete(:feed_original_url)
    @folder_id       = session.delete(:feed_folder_id)
    redirect_to new_feed_path if @feed_candidates.blank?
  end

  def create
    raw_url = feed_url
    folder_id = params.dig(:feed, :folder_id).to_i.nonzero?

    if raw_url.blank?
      @feed = Feed.new
      @feed.errors.add(:url, :blank)
      @folders = Current.user.folders.order(:name)
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
      session[:feed_candidates] = feed_urls
      session[:feed_original_url] = raw_url
      session[:feed_folder_id] = folder_id
      redirect_to select_feeds_path
    end
  rescue Feed::SsrfError
    @feed = Feed.new(url: raw_url)
    @feed.errors.add(:url, "cannot point to private network")
    @folders = Current.user.folders.order(:name)
    render :new, status: :unprocessable_entity
  end

  def edit
    @subscription = Current.user.subscriptions.includes(:feed).find_by!(feed_id: params[:id])
    @feed = @subscription.feed
    @folders = Current.user.folders.order(:name)
  end

  def update
    @subscription = Current.user.subscriptions.find_by!(feed_id: params[:id])
    @feed = @subscription.feed

    Feed.transaction do
      # fetch_interval_minutes はフィードのグローバル設定（全購読者に影響）
      if params[:feed].present?
        @feed.update!(params.require(:feed).permit(:fetch_interval_minutes))
      end

      if params[:subscription].present?
        @subscription.update!(params.require(:subscription).permit(:title, :rate, :folder_id))
      end
    end

    redirect_to feeds_path, notice: "フィードを更新しました。"
  rescue ActiveRecord::RecordInvalid
    @folders = Current.user.folders.order(:name)
    render :edit, status: :unprocessable_entity
  end

  def destroy
    subscription = Current.user.subscriptions.find_by!(feed_id: params[:id])
    feed = subscription.feed
    Feed.transaction do
      subscription.destroy!
      feed.destroy if feed.subscriptions.reload.none?
    end
    redirect_to feeds_path, notice: "フィードを削除しました。"
  end

  private

  def feed_url
    params.require(:feed).permit(:url)[:url].to_s.strip
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
    @feed = Feed.find_by(url: url) || Feed.subscribe(url)

    unless @feed.persisted?
      unless @feed.save
        @folders = Current.user.folders.order(:name)
        return render :new, status: :unprocessable_entity
      end
    end

    folder = folder_id ? Current.user.folders.find_by(id: folder_id) : nil
    subscription = Current.user.subscribe_to(@feed, folder: folder)

    notice = subscription.previously_new_record? ? "フィードを追加しました。" : "既に登録済みのフィードです。"
    redirect_to feeds_path, notice: notice
  end
end
