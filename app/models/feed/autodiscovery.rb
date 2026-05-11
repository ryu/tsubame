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

  GUESS_PATHS = %w[
    /feed
    /feed.xml
    /feed.atom
    /rss
    /rss.xml
    /atom.xml
    /index.xml
  ].freeze

  GUESS_TIMEOUT = 5

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
    feed_urls = guess_feed_urls(uri) if feed_urls.empty?
    { feed_urls: feed_urls, content_type: :html }
  end

  private

  # build_http is provided by Feed::Fetching (included in the same model)
  def perform_html_request(uri, resolved_ip)
    http = build_http(uri, resolved_ip)

    request = Net::HTTP::Get.new(uri)
    request["User-Agent"] = Feed::Fetching::USER_AGENT
    request["Accept"] = "text/html,application/xhtml+xml"
    request["Accept-Encoding"] = "identity"

    response = http.request(request)
    body = extract_head_section(response.body) if response.is_a?(Net::HTTPSuccess)

    [ response, body ]
  end

  def extract_head_section(body)
    body = body.byteslice(0, MAX_HTML_PROBE_SIZE) if body.bytesize > MAX_HTML_PROBE_SIZE
    if (head_end = body.index("</head>"))
      body.byteslice(0, head_end + "</head>".length)
    else
      body
    end
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

  # <link> タグが見つからない場合のフォールバック。
  # よくあるフィードパスに HEAD リクエストを送り、Content-Type で判定する。
  def guess_feed_urls(base_uri)
    base = "#{base_uri.scheme}://#{base_uri.host}"
    base << ":#{base_uri.port}" unless base_uri.default_port == base_uri.port

    urls = []
    GUESS_PATHS.each do |path|
      guess_uri = URI.parse("#{base}#{path}")
      resolved_ip = validate_url_safety!(guess_uri)

      http = build_http(guess_uri, resolved_ip, open_timeout: GUESS_TIMEOUT, read_timeout: GUESS_TIMEOUT)

      response = http.head(guess_uri.request_uri)
      next unless response.is_a?(Net::HTTPSuccess)

      ct = response["Content-Type"].to_s.split(";").first.to_s.strip.downcase
      urls << guess_uri.to_s if FEED_CONTENT_TYPES.include?(ct)
    rescue Feed::SsrfError, URI::InvalidURIError, Net::OpenTimeout,
           Net::ReadTimeout, SocketError, Errno::ECONNREFUSED,
           Errno::EHOSTUNREACH, Errno::ECONNRESET, OpenSSL::SSL::SSLError
      next
    end
    urls
  end
end
