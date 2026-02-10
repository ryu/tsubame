class FeedsController < ApplicationController
  def index
    @feeds = Feed.all.order(:title)
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
end
