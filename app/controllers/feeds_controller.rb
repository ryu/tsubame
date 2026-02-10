class FeedsController < ApplicationController
  def index
    @feeds = Feed.all.order(:title)
  end

  def new
    @feed = Feed.new
  end

  def create
    @feed = Feed.new(url: params.require(:feed).permit(:url)[:url])
    @feed.next_fetch_at = Time.current
    if @feed.save
      redirect_to feeds_path, notice: "フィードを追加しました。"
    else
      render :new, status: :unprocessable_entity
    end
  end

  def edit
    @feed = Feed.find(params[:id])
  end

  def update
    @feed = Feed.find(params[:id])
    if @feed.update(params.require(:feed).permit(:title))
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

  def import
  end

  def create_import
    file = params[:opml_file]

    if file.blank?
      redirect_to import_feeds_path, alert: "ファイルを選択してください。"
      return
    end

    if file.size > 5.megabytes
      redirect_to import_feeds_path, alert: "ファイルサイズは5MB以下にしてください。"
      return
    end

    result = Feed.import_from_opml(file.read)
    redirect_to feeds_path, notice: "#{result[:added]}件のフィードを追加しました。（#{result[:skipped]}件スキップ）"
  rescue => e
    Rails.logger.error("OPML import failed: #{e.class} - #{e.message}")
    redirect_to import_feeds_path, alert: "インポートに失敗しました。ファイル形式を確認してください。"
  end

  def export
    send_data Feed.to_opml,
      filename: "subscriptions.opml",
      type: "application/xml",
      disposition: "attachment"
  end

  def mark_all_as_read
    @feed = Feed.find(params[:id])
    count = @feed.mark_all_entries_as_read!
    render json: { success: true, marked_count: count }
  end

  def fetch_now
    @feed = Feed.find(params[:id])
    FetchFeedJob.perform_now(@feed.id)
    @feed.reload
    redirect_to feeds_path, notice: "「#{@feed.title || @feed.url}」をフェッチしました。"
  rescue => e
    redirect_to feeds_path, alert: "フェッチに失敗しました。"
  end
end
