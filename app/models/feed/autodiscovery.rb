require "net/http"
require "uri"

module Feed::Autodiscovery
  extend ActiveSupport::Concern

  MAX_HTML_PROBE_SIZE = 512.kilobytes

  FEED_CONTENT_TYPES = %w[
    application/rss+xml
    application/atom+xml
    text/xml
    application/xml
  ].freeze

  # URL を受け取り、フィード URL の候補リストを返す。
  # 戻り値:
  #   { feed_urls: ["https://..."], content_type: :feed }   — URL 自体がフィード
  #   { feed_urls: ["https://...", ...], content_type: :html } — HTML からフィードを検出
  #   { feed_urls: [], content_type: :html }                 — HTML だがフィードなし
  #   { feed_urls: [], content_type: :unknown }              — 不明な Content-Type
  #
  # SSRF エラー時は Feed::SsrfError を raise（呼び出し元でハンドリングする）。
  # ネットワーク接続エラー時は StandardError を raise。
  def discover_from(url)
    uri = URI.parse(url)
    resolved_ip = validate_url_safety!(uri)
    response, body = perform_html_request(uri, resolved_ip)

    return { feed_urls: [], content_type: :unknown } unless response.is_a?(Net::HTTPSuccess)

    content_type = response.content_type.to_s.split(";").first.to_s.strip.downcase

    if FEED_CONTENT_TYPES.include?(content_type)
      return { feed_urls: [ url ], content_type: :feed }
    end

    return { feed_urls: [], content_type: :unknown } unless content_type == "text/html"

    feed_urls = extract_feed_links(body, url)
    { feed_urls: feed_urls, content_type: :html }
  end

  private

  # HTML 専用リクエスト: MAX_HTML_PROBE_SIZE で打ち切り、</head> で早期終了
  def perform_html_request(uri, resolved_ip)
    http = Net::HTTP.new(uri.host, uri.port)
    http.ipaddr = resolved_ip
    http.use_ssl = (uri.scheme == "https")
    http.open_timeout = Feed::Fetching::OPEN_TIMEOUT
    http.read_timeout = Feed::Fetching::READ_TIMEOUT

    request = Net::HTTP::Get.new(uri)
    request["User-Agent"] = Feed::Fetching::USER_AGENT
    request["Accept"] = "text/html,application/xhtml+xml"

    result_response = nil
    result_body = nil

    http.request(request) do |response|
      result_body = read_html_with_limit!(response) if response.is_a?(Net::HTTPSuccess)
      result_response = response
    end

    [ result_response, result_body ]
  end

  # MAX_HTML_PROBE_SIZE または </head> 到達で読み込みを打ち切る
  def read_html_with_limit!(response)
    body = +""
    response.read_body do |chunk|
      body << chunk
      raise "HTML response too large" if body.bytesize > MAX_HTML_PROBE_SIZE
      break if body.include?("</head>")
    end
    body
  end

  # <link rel="alternate" type="application/...+xml" href="..."> を抽出
  # 属性の順序が異なる場合（type が先、rel が後）にも対応する
  def extract_feed_links(html, base_url)
    urls = []
    html.scan(/<link\s[^>]*>/i) do |tag|
      next unless tag.match?(/rel\s*=\s*["']alternate["']/i)
      next unless tag.match?(/type\s*=\s*["'](application\/rss\+xml|application\/atom\+xml)["']/i)

      if (href_match = tag.match(/href\s*=\s*["']([^"']+)["']/i))
        href = href_match[1]
        absolute_url = URI.join(base_url, href).to_s
        urls << absolute_url
      end
    end
    urls.uniq
  end
end
