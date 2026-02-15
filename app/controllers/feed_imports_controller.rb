class FeedImportsController < ApplicationController
  def new
  end

  def create
    file = params[:opml_file]

    return redirect_with_alert("ファイルを選択してください。") if file.blank?
    return redirect_with_alert("ファイルサイズは5MB以下にしてください。") if file.size > 5.megabytes

    content = file.read
    stripped = content.sub(/\A\xEF\xBB\xBF/n, "").lstrip
    return redirect_with_alert("XMLファイルを選択してください。") unless stripped.match?(/\A(<\?xml|<opml[\s>])/i)

    result = Feed.import_from_opml(content)
    redirect_to feeds_path, notice: "#{result[:added]}件のフィードを追加しました。（#{result[:skipped]}件スキップ）"
  rescue Feed::Opml::ImportError => e
    Rails.logger.error("OPML import failed: #{e.message}")
    redirect_with_alert("インポートに失敗しました。ファイル形式を確認してください。")
  end

  private

  def redirect_with_alert(message)
    redirect_to new_feed_import_path, alert: message
  end
end
