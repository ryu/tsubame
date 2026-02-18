require "test_helper"

class Feed::AutodiscoveryTest < ActiveSupport::TestCase
  private

  def stub_guess_paths_not_found(host)
    Feed::Autodiscovery::GUESS_PATHS.each do |path|
      stub_request(:head, "#{host}#{path}").to_return(status: 404)
    end
  end

  public

  # === Direct Feed URL Tests ===

  test "discover_from returns :feed content_type for RSS feed URL" do
    rss_content = <<~RSS
      <?xml version="1.0"?>
      <rss version="2.0">
        <channel>
          <title>Example Feed</title>
          <link>https://example.com</link>
          <description>Test</description>
        </channel>
      </rss>
    RSS

    stub_request(:get, "https://example.com/feed.xml")
      .to_return(
        status: 200,
        body: rss_content,
        headers: { "Content-Type" => "application/rss+xml" }
      )

    result = Feed.new.discover_from("https://example.com/feed.xml")

    assert_equal :feed, result[:content_type]
    assert_equal [ "https://example.com/feed.xml" ], result[:feed_urls]
  end

  test "discover_from returns :feed content_type for Atom feed URL" do
    atom_content = <<~ATOM
      <?xml version="1.0"?>
      <feed xmlns="http://www.w3.org/2005/Atom">
        <title>Example Feed</title>
        <link href="https://example.com"/>
      </feed>
    ATOM

    stub_request(:get, "https://example.com/feed.atom")
      .to_return(
        status: 200,
        body: atom_content,
        headers: { "Content-Type" => "application/atom+xml" }
      )

    result = Feed.new.discover_from("https://example.com/feed.atom")

    assert_equal :feed, result[:content_type]
    assert_equal [ "https://example.com/feed.atom" ], result[:feed_urls]
  end

  test "discover_from handles text/xml content type" do
    xml_content = '<?xml version="1.0"?><rss version="2.0"><channel><title>Test</title></channel></rss>'

    stub_request(:get, "https://example.com/feed.xml")
      .to_return(
        status: 200,
        body: xml_content,
        headers: { "Content-Type" => "text/xml" }
      )

    result = Feed.new.discover_from("https://example.com/feed.xml")

    assert_equal :feed, result[:content_type]
    assert_equal [ "https://example.com/feed.xml" ], result[:feed_urls]
  end

  test "discover_from handles application/xml content type" do
    xml_content = '<?xml version="1.0"?><rss version="2.0"><channel><title>Test</title></channel></rss>'

    stub_request(:get, "https://example.com/feed.xml")
      .to_return(
        status: 200,
        body: xml_content,
        headers: { "Content-Type" => "application/xml" }
      )

    result = Feed.new.discover_from("https://example.com/feed.xml")

    assert_equal :feed, result[:content_type]
  end

  # === HTML Page with Feed Links ===

  test "discover_from detects single feed link from HTML" do
    html_content = <<~HTML
      <!DOCTYPE html>
      <html>
        <head>
          <title>My Blog</title>
          <link rel="alternate" type="application/rss+xml" href="/feed.xml">
        </head>
        <body>
          <h1>Welcome</h1>
        </body>
      </html>
    HTML

    stub_request(:get, "https://example.com/blog")
      .to_return(
        status: 200,
        body: html_content,
        headers: { "Content-Type" => "text/html; charset=utf-8" }
      )

    result = Feed.new.discover_from("https://example.com/blog")

    assert_equal :html, result[:content_type]
    assert_equal 1, result[:feed_urls].size
    assert_equal "https://example.com/feed.xml", result[:feed_urls].first
  end

  test "discover_from detects multiple feed links from HTML" do
    html_content = <<~HTML
      <!DOCTYPE html>
      <html>
        <head>
          <title>Multi Feed Blog</title>
          <link rel="alternate" type="application/rss+xml" href="https://example.com/rss">
          <link rel="alternate" type="application/atom+xml" href="https://example.com/atom">
        </head>
      </html>
    HTML

    stub_request(:get, "https://example.com/multi")
      .to_return(
        status: 200,
        body: html_content,
        headers: { "Content-Type" => "text/html; charset=utf-8" }
      )

    result = Feed.new.discover_from("https://example.com/multi")

    assert_equal :html, result[:content_type]
    assert_equal 2, result[:feed_urls].size
    assert_includes result[:feed_urls], "https://example.com/rss"
    assert_includes result[:feed_urls], "https://example.com/atom"
  end

  test "discover_from returns empty feed_urls when HTML has no feed links" do
    html_content = <<~HTML
      <!DOCTYPE html>
      <html>
        <head>
          <title>No Feed Blog</title>
        </head>
        <body>
          <h1>Content</h1>
        </body>
      </html>
    HTML

    stub_request(:get, "https://example.com/nofeed")
      .to_return(
        status: 200,
        body: html_content,
        headers: { "Content-Type" => "text/html; charset=utf-8" }
      )
    stub_guess_paths_not_found("https://example.com")

    result = Feed.new.discover_from("https://example.com/nofeed")

    assert_equal :html, result[:content_type]
    assert_equal [], result[:feed_urls]
  end

  # === Relative URL Conversion ===

  test "discover_from converts relative URLs to absolute" do
    html_content = <<~HTML
      <!DOCTYPE html>
      <html>
        <head>
          <link rel="alternate" type="application/rss+xml" href="/rss">
          <link rel="alternate" type="application/atom+xml" href="feed.atom">
        </head>
      </html>
    HTML

    stub_request(:get, "https://example.com/blog/page")
      .to_return(
        status: 200,
        body: html_content,
        headers: { "Content-Type" => "text/html; charset=utf-8" }
      )

    result = Feed.new.discover_from("https://example.com/blog/page")

    assert_equal 2, result[:feed_urls].size
    assert_includes result[:feed_urls], "https://example.com/rss"
    assert_includes result[:feed_urls], "https://example.com/blog/feed.atom"
  end

  test "discover_from preserves absolute URLs in href" do
    html_content = <<~HTML
      <!DOCTYPE html>
      <html>
        <head>
          <link rel="alternate" type="application/rss+xml" href="https://other.com/feed.xml">
        </head>
      </html>
    HTML

    stub_request(:get, "https://example.com/")
      .to_return(
        status: 200,
        body: html_content,
        headers: { "Content-Type" => "text/html; charset=utf-8" }
      )

    result = Feed.new.discover_from("https://example.com/")

    assert_equal 1, result[:feed_urls].size
    assert_equal "https://other.com/feed.xml", result[:feed_urls].first
  end

  # === Attribute Order Variations ===

  test "discover_from detects feed links when type comes before rel" do
    html_content = <<~HTML
      <!DOCTYPE html>
      <html>
        <head>
          <link type="application/rss+xml" rel="alternate" href="/feed.xml">
        </head>
      </html>
    HTML

    stub_request(:get, "https://example.com/page")
      .to_return(
        status: 200,
        body: html_content,
        headers: { "Content-Type" => "text/html; charset=utf-8" }
      )

    result = Feed.new.discover_from("https://example.com/page")

    assert_equal 1, result[:feed_urls].size
    assert_equal "https://example.com/feed.xml", result[:feed_urls].first
  end

  test "discover_from detects feed links with extra whitespace in attributes" do
    html_content = <<~HTML
      <!DOCTYPE html>
      <html>
        <head>
          <link rel = "alternate" type = "application/rss+xml" href = "/feed.xml" >
        </head>
      </html>
    HTML

    stub_request(:get, "https://example.com/page")
      .to_return(
        status: 200,
        body: html_content,
        headers: { "Content-Type" => "text/html; charset=utf-8" }
      )

    result = Feed.new.discover_from("https://example.com/page")

    assert_equal 1, result[:feed_urls].size
    assert_equal "https://example.com/feed.xml", result[:feed_urls].first
  end

  # === Deduplication ===

  test "discover_from deduplicates identical feed URLs" do
    html_content = <<~HTML
      <!DOCTYPE html>
      <html>
        <head>
          <link rel="alternate" type="application/rss+xml" href="/feed.xml">
          <link rel="alternate" type="application/rss+xml" href="/feed.xml">
        </head>
      </html>
    HTML

    stub_request(:get, "https://example.com/page")
      .to_return(
        status: 200,
        body: html_content,
        headers: { "Content-Type" => "text/html; charset=utf-8" }
      )

    result = Feed.new.discover_from("https://example.com/page")

    assert_equal 1, result[:feed_urls].size
    assert_equal "https://example.com/feed.xml", result[:feed_urls].first
  end

  # === Non-matching HTML ===

  test "discover_from ignores feed links without rel=alternate" do
    html_content = <<~HTML
      <!DOCTYPE html>
      <html>
        <head>
          <link type="application/rss+xml" href="/feed.xml">
        </head>
      </html>
    HTML

    stub_request(:get, "https://example.com/page")
      .to_return(
        status: 200,
        body: html_content,
        headers: { "Content-Type" => "text/html; charset=utf-8" }
      )
    stub_guess_paths_not_found("https://example.com")

    result = Feed.new.discover_from("https://example.com/page")

    assert_equal 0, result[:feed_urls].size
  end

  test "discover_from ignores links without proper feed type" do
    html_content = <<~HTML
      <!DOCTYPE html>
      <html>
        <head>
          <link rel="alternate" type="text/html" href="/feed.xml">
        </head>
      </html>
    HTML

    stub_request(:get, "https://example.com/page")
      .to_return(
        status: 200,
        body: html_content,
        headers: { "Content-Type" => "text/html; charset=utf-8" }
      )
    stub_guess_paths_not_found("https://example.com")

    result = Feed.new.discover_from("https://example.com/page")

    assert_equal 0, result[:feed_urls].size
  end

  # === SSRF Protection ===

  test "discover_from raises Feed::SsrfError for loopback address" do
    assert_raises(Feed::SsrfError) do
      Feed.new.discover_from("http://127.0.0.1/feed.xml")
    end
  end

  test "discover_from raises Feed::SsrfError for private network address" do
    assert_raises(Feed::SsrfError) do
      Feed.new.discover_from("http://192.168.1.1/feed.xml")
    end
  end

  test "discover_from raises Feed::SsrfError for link-local address" do
    assert_raises(Feed::SsrfError) do
      Feed.new.discover_from("http://169.254.169.254/feed.xml")
    end
  end

  test "discover_from raises Feed::SsrfError when hostname resolves to private IP" do
    # Mock DNS resolution to return a private IP for internal.example.com
    original_getaddress = Resolv.method(:getaddress)

    Resolv.define_singleton_method(:getaddress) do |host|
      if host == "internal.example.com"
        "192.168.1.100"
      else
        original_getaddress.call(host)
      end
    end

    begin
      assert_raises(Feed::SsrfError) do
        Feed.new.discover_from("http://internal.example.com/feed.xml")
      end
    ensure
      Resolv.define_singleton_method(:getaddress, original_getaddress)
    end
  end

  # === Non-Success HTTP Status ===

  test "discover_from returns unknown content_type for 404 response" do
    stub_request(:get, "https://example.com/notfound")
      .to_return(
        status: 404,
        body: "Not Found",
        headers: { "Content-Type" => "text/html; charset=utf-8" }
      )

    result = Feed.new.discover_from("https://example.com/notfound")

    assert_equal :unknown, result[:content_type]
    assert_equal [], result[:feed_urls]
  end

  test "discover_from returns unknown content_type for 500 response" do
    stub_request(:get, "https://example.com/error")
      .to_return(
        status: 500,
        body: "Server Error",
        headers: { "Content-Type" => "text/html; charset=utf-8" }
      )

    result = Feed.new.discover_from("https://example.com/error")

    assert_equal :unknown, result[:content_type]
    assert_equal [], result[:feed_urls]
  end

  # === Unknown Content Type ===

  test "discover_from returns unknown content_type for unrecognized MIME type" do
    stub_request(:get, "https://example.com/data")
      .to_return(
        status: 200,
        body: "some data",
        headers: { "Content-Type" => "application/octet-stream" }
      )

    result = Feed.new.discover_from("https://example.com/data")

    assert_equal :unknown, result[:content_type]
    assert_equal [], result[:feed_urls]
  end

  test "discover_from handles missing Content-Type header" do
    stub_request(:get, "https://example.com/noctype")
      .to_return(
        status: 200,
        body: "some content",
        headers: {}
      )

    result = Feed.new.discover_from("https://example.com/noctype")

    assert_equal :unknown, result[:content_type]
    assert_equal [], result[:feed_urls]
  end

  # === Edge Cases ===

  test "discover_from handles Content-Type with charset parameter" do
    rss_content = '<?xml version="1.0"?><rss version="2.0"><channel><title>Test</title></channel></rss>'

    stub_request(:get, "https://example.com/feed.xml")
      .to_return(
        status: 200,
        body: rss_content,
        headers: { "Content-Type" => "application/rss+xml; charset=utf-8" }
      )

    result = Feed.new.discover_from("https://example.com/feed.xml")

    assert_equal :feed, result[:content_type]
  end

  test "discover_from handles mixed case Content-Type" do
    rss_content = '<?xml version="1.0"?><rss version="2.0"><channel><title>Test</title></channel></rss>'

    stub_request(:get, "https://example.com/feed.xml")
      .to_return(
        status: 200,
        body: rss_content,
        headers: { "Content-Type" => "Application/RSS+XML" }
      )

    result = Feed.new.discover_from("https://example.com/feed.xml")

    assert_equal :feed, result[:content_type]
  end

  test "discover_from raises StandardError for network timeout" do
    stub_request(:get, "https://example.com/slow")
      .to_timeout

    assert_raises(StandardError) do
      Feed.new.discover_from("https://example.com/slow")
    end
  end

  # === URL Guessing Fallback ===

  test "discover_from guesses /feed when HTML has no feed links" do
    html_content = "<!DOCTYPE html><html><head><title>Blog</title></head><body></body></html>"

    stub_request(:get, "https://example.com/blog")
      .to_return(status: 200, body: html_content, headers: { "Content-Type" => "text/html" })
    stub_guess_paths_not_found("https://example.com")
    stub_request(:head, "https://example.com/feed")
      .to_return(status: 200, headers: { "Content-Type" => "application/rss+xml" })

    result = Feed.new.discover_from("https://example.com/blog")

    assert_equal :html, result[:content_type]
    assert_includes result[:feed_urls], "https://example.com/feed"
  end

  test "discover_from guesses /atom.xml with atom content type" do
    html_content = "<!DOCTYPE html><html><head><title>Blog</title></head><body></body></html>"

    stub_request(:get, "https://example.com/blog")
      .to_return(status: 200, body: html_content, headers: { "Content-Type" => "text/html" })
    stub_guess_paths_not_found("https://example.com")
    stub_request(:head, "https://example.com/atom.xml")
      .to_return(status: 200, headers: { "Content-Type" => "application/atom+xml" })

    result = Feed.new.discover_from("https://example.com/blog")

    assert_includes result[:feed_urls], "https://example.com/atom.xml"
  end

  test "discover_from skips guessing when link tags found" do
    html_content = <<~HTML
      <!DOCTYPE html>
      <html><head>
        <link rel="alternate" type="application/rss+xml" href="/feed.xml">
      </head></html>
    HTML

    stub_request(:get, "https://example.com/blog")
      .to_return(status: 200, body: html_content, headers: { "Content-Type" => "text/html" })
    # No HEAD stubs — if guessing runs, webmock will raise

    result = Feed.new.discover_from("https://example.com/blog")

    assert_equal [ "https://example.com/feed.xml" ], result[:feed_urls]
  end

  test "discover_from returns empty when all guess paths return 404" do
    html_content = "<!DOCTYPE html><html><head><title>Blog</title></head><body></body></html>"

    stub_request(:get, "https://example.com/blog")
      .to_return(status: 200, body: html_content, headers: { "Content-Type" => "text/html" })
    stub_guess_paths_not_found("https://example.com")

    result = Feed.new.discover_from("https://example.com/blog")

    assert_equal [], result[:feed_urls]
  end

  test "discover_from handles guess timeout without raising" do
    html_content = "<!DOCTYPE html><html><head><title>Blog</title></head><body></body></html>"

    stub_request(:get, "https://example.com/blog")
      .to_return(status: 200, body: html_content, headers: { "Content-Type" => "text/html" })

    Feed::Autodiscovery::GUESS_PATHS.each do |path|
      stub_request(:head, "https://example.com#{path}").to_timeout
    end

    result = Feed.new.discover_from("https://example.com/blog")

    assert_equal :html, result[:content_type]
    assert_equal [], result[:feed_urls]
  end

  test "discover_from collects multiple guessed feed URLs" do
    html_content = "<!DOCTYPE html><html><head><title>Blog</title></head><body></body></html>"

    stub_request(:get, "https://example.com/blog")
      .to_return(status: 200, body: html_content, headers: { "Content-Type" => "text/html" })
    stub_guess_paths_not_found("https://example.com")
    stub_request(:head, "https://example.com/feed")
      .to_return(status: 200, headers: { "Content-Type" => "application/rss+xml" })
    stub_request(:head, "https://example.com/rss.xml")
      .to_return(status: 200, headers: { "Content-Type" => "application/rss+xml" })

    result = Feed.new.discover_from("https://example.com/blog")

    assert_includes result[:feed_urls], "https://example.com/feed"
    assert_includes result[:feed_urls], "https://example.com/rss.xml"
  end
end
