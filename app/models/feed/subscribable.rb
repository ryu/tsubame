class Feed::UnreachableError < StandardError; end

module Feed::Subscribable
  extend ActiveSupport::Concern

  Resolution = Struct.new(:feed, :candidates, keyword_init: true) do
    def candidates? = candidates.present?
  end

  class_methods do
    def resolve(url)
      candidates = candidate_urls(url)

      case candidates.length
      when 0, 1
        Resolution.new(feed: find_or_subscribe(candidates.first || url))
      else
        Resolution.new(candidates: candidates)
      end
    end

    def find_or_subscribe(url)
      find_by(url: url) || subscribe(url)
    end

    private

    def candidate_urls(url)
      result = new.discover_from(url)
      result[:content_type] == :feed ? [ url ] : Array(result[:feed_urls])
    rescue URI::InvalidURIError
      []
    rescue *Feed::Fetching::NETWORK_ERRORS => e
      Rails.error.report(e, handled: true, severity: :warning,
        source: "feed.autodiscovery", context: { url: url })
      Rails.logger.warn("Feed autodiscovery failed for #{url}: #{e.message}")
      raise Feed::UnreachableError, e.message
    end
  end
end
