module Feed::Subscribable
  extend ActiveSupport::Concern

  # URL からフィードを購読する際の解決結果。
  #   feed       — 購読すべき Feed（subscribe 可能なときのみ存在）
  #   candidates — 候補が複数あり、ユーザーに選ばせる必要がある URL のリスト
  # candidates が存在する場合は feed は nil。
  Resolution = Struct.new(:feed, :candidates, keyword_init: true) do
    def candidates? = candidates.present?
  end

  class_methods do
    # 入力 URL からフィードを解決する。
    #   - URL 自体がフィード、または候補が 1 つだけ → その URL の Feed を find_or_subscribe
    #   - 候補が複数            → candidates を返してユーザーに選ばせる
    #   - 候補なし              → 入力 URL をそのまま Feed として find_or_subscribe
    #
    # SSRF 検出時は Feed::SsrfError を raise する。
    def resolve(url)
      candidates = candidate_urls(url)

      case candidates.length
      when 0, 1
        Resolution.new(feed: find_or_subscribe(candidates.first || url))
      else
        Resolution.new(candidates: candidates)
      end
    end

    # URL の Feed を取得し、なければ未保存のフィードを subscribe 用に組み立てて返す。
    def find_or_subscribe(url)
      find_by(url: url) || subscribe(url)
    end

    private

    # オートディスカバリでフィード候補を集める。
    # SSRF はそのまま伝播。その他のネットワークエラーは候補なし扱い。
    def candidate_urls(url)
      result = new.discover_from(url)
      result[:content_type] == :feed ? [ url ] : Array(result[:feed_urls])
    rescue Feed::SsrfError
      raise
    rescue StandardError => e
      Rails.error.report(e, handled: true, severity: :warning,
        source: "feed.autodiscovery", context: { url: url })
      Rails.logger.warn("Feed autodiscovery failed for #{url}: #{e.message}")
      []
    end
  end
end
