class FeedImportsController < ApplicationController
  def new
  end

  def create
    result = Feed.import_from_opml(opml_content, user: Current.user)
    redirect_to feeds_path, notice: "#{result[:added]}件のフィードを追加しました。（#{result[:skipped]}件スキップ）"
  rescue Feed::Opml::ImportError => e
    redirect_with_alert(e.message)
  end

  private

  def opml_content
    file = params[:opml_file]
    raise Feed::Opml::ImportError, "ファイルを選択してください。" if file.blank?
    raise Feed::Opml::ImportError, "ファイルサイズは5MB以下にしてください。" if file.size > 5.megabytes

    file.read
  end

  def redirect_with_alert(message)
    redirect_to new_feed_import_path, alert: message
  end
end
