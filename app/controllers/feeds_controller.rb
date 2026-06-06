class FeedsController < ApplicationController
  def index
    @subscriptions = Current.user.subscriptions.includes(:feed).joins(:feed).merge(Feed.order(:title))
  end

  def new
    @feed = Feed.new
    @folders = Current.user.folders.order(:name)
  end

  def create
    @feed = Feed.new(url: feed_url)
    return render_new_with_error(:blank) if @feed.url.blank?

    resolution = Feed.resolve(@feed.url)

    if resolution.candidates?
      @feed_candidates = resolution.candidates
      @folders = Current.user.folders.order(:name)
      return render :select
    end

    subscribe(resolution.feed)
  rescue Feed::SsrfError
    render_new_with_error("cannot point to private network")
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

  def folder
    folder_id = params.dig(:feed, :folder_id).to_i.nonzero?
    folder_id && Current.user.folders.find_by(id: folder_id)
  end

  def subscribe(feed)
    @feed = feed

    unless @feed.persisted? || @feed.save
      @folders = Current.user.folders.order(:name)
      return render :new, status: :unprocessable_entity
    end

    subscription = Current.user.subscribe_to(@feed, folder: folder)
    notice = subscription.previously_new_record? ? "フィードを追加しました。" : "既に登録済みのフィードです。"
    redirect_to feeds_path, notice: notice
  end

  def render_new_with_error(error)
    @feed.errors.add(:url, error)
    @folders = Current.user.folders.order(:name)
    render :new, status: :unprocessable_entity
  end
end
