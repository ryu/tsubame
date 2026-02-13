require "test_helper"

class FeedTest < ActiveSupport::TestCase
  test "should be valid with required attributes" do
    feed = Feed.new(url: "https://example.com/feed.xml")
    assert feed.valid?
  end

  test "should require url" do
    feed = Feed.new(url: nil)
    assert_not feed.valid?
    assert_includes feed.errors[:url], "を入力してください"
  end

  test "should enforce unique url" do
    existing = feeds(:ruby_blog)
    feed = Feed.new(url: existing.url)
    assert_not feed.valid?
    assert_includes feed.errors[:url], "はすでに存在します"
  end

  test "should reject non-HTTP URLs" do
    feed = Feed.new(url: "ftp://example.com/feed.xml")
    assert_not feed.valid?
    assert_includes feed.errors[:url], "must be an HTTP or HTTPS URL"
  end

  test "should reject invalid URLs" do
    feed = Feed.new(url: "not a url at all ://")
    assert_not feed.valid?
  end

  test "should accept HTTPS URLs" do
    feed = Feed.new(url: "https://example.com/feed.xml")
    assert feed.valid?
  end

  test "should accept HTTP URLs" do
    feed = Feed.new(url: "http://example.com/feed.xml")
    assert feed.valid?
  end

  test "should reject loopback URL" do
    feed = Feed.new(url: "http://127.0.0.1/feed.xml")
    assert_not feed.valid?
    assert_includes feed.errors[:url], "cannot point to private network"
  end

  test "should reject private network URL" do
    feed = Feed.new(url: "http://192.168.1.1/feed.xml")
    assert_not feed.valid?
    assert_includes feed.errors[:url], "cannot point to private network"
  end

  test "should reject link-local URL" do
    feed = Feed.new(url: "http://169.254.169.254/latest/meta-data/")
    assert_not feed.valid?
    assert_includes feed.errors[:url], "cannot point to private network"
  end

  test "should reject IPv6 loopback URL" do
    feed = Feed.new(url: "http://[::1]/feed.xml")
    assert_not feed.valid?
    assert_includes feed.errors[:url], "cannot point to private network"
  end

  test "private_ip? should detect loopback addresses" do
    assert Feed.private_ip?("127.0.0.1")
  end

  test "private_ip? should detect private network addresses" do
    assert Feed.private_ip?("10.0.0.1")
    assert Feed.private_ip?("192.168.1.1")
    assert Feed.private_ip?("172.16.0.1")
  end

  test "private_ip? should detect link-local addresses" do
    assert Feed.private_ip?("169.254.169.254")
  end

  test "private_ip? should allow public addresses" do
    assert_not Feed.private_ip?("93.184.216.34")
  end

  test "should normalize url by stripping whitespace" do
    feed = Feed.create!(url: "  https://example.com/feed.xml  ")
    assert_equal "https://example.com/feed.xml", feed.url
  end

  test "should have ok status by default" do
    feed = Feed.create!(url: "https://example.com/feed.xml")
    assert feed.ok?
    assert_equal "ok", feed.status
  end

  test "should allow error status" do
    feed = feeds(:error_feed)
    assert feed.error?
    assert_equal "error", feed.status
  end

  test "should destroy associated entries when destroyed" do
    feed = feeds(:ruby_blog)
    assert_difference "Entry.count", -2 do
      feed.destroy
    end
  end

  test "should have many entries" do
    feed = feeds(:ruby_blog)
    assert_equal 2, feed.entries.count
  end

  test "import_from_opml should import feeds from valid OPML" do
    opml_content = file_fixture("sample.opml").read

    assert_difference "Feed.count", 3 do
      result = Feed.import_from_opml(opml_content)
      assert_equal 3, result[:added]
      assert_equal 0, result[:skipped]
    end

    # Verify feed attributes
    techcrunch = Feed.find_by(url: "https://techcrunch.com/feed/")
    assert_equal "TechCrunch", techcrunch.title
    assert_equal "https://techcrunch.com/", techcrunch.site_url
    assert techcrunch.ok?
    assert_not_nil techcrunch.next_fetch_at
  end

  test "import_from_opml should skip duplicate feeds" do
    opml_content = file_fixture("sample.opml").read

    # First import
    Feed.import_from_opml(opml_content)

    # Second import should skip all
    assert_no_difference "Feed.count" do
      result = Feed.import_from_opml(opml_content)
      assert_equal 0, result[:added]
      assert_equal 3, result[:skipped]
    end
  end

  test "import_from_opml should handle nested outlines" do
    opml_content = file_fixture("sample.opml").read

    result = Feed.import_from_opml(opml_content)

    # Should import both nested feeds from "Tech News" folder
    assert Feed.exists?(url: "https://techcrunch.com/feed/")
    assert Feed.exists?(url: "https://news.ycombinator.com/rss")
    # And the top-level feed
    assert Feed.exists?(url: "https://rubyweekly.com/rss")
  end

  test "import_from_opml should skip invalid feeds and continue" do
    opml_content = <<~OPML
      <?xml version="1.0"?>
      <opml version="1.0">
        <body>
          <outline type="rss" xmlUrl="http://127.0.0.1/evil" title="Private IP Feed"/>
          <outline type="rss" xmlUrl="https://example.com/good-feed.xml" title="Good Feed"/>
        </body>
      </opml>
    OPML

    result = Feed.import_from_opml(opml_content)
    assert_equal 1, result[:added]
    assert_equal 1, result[:skipped]
    assert Feed.exists?(url: "https://example.com/good-feed.xml")
    assert_not Feed.exists?(url: "http://127.0.0.1/evil")
  end

  test "import_from_opml should raise error for invalid XML" do
    invalid_xml = "<invalid>not closed"

    assert_raises(Feed::Opml::ImportError) do
      Feed.import_from_opml(invalid_xml)
    end
  end

  test "due_for_fetch scope should return feeds due for fetching" do
    feed_due = feeds(:ruby_blog)
    feed_due.update!(next_fetch_at: 1.minute.ago)

    feed_not_due = feeds(:error_feed)
    feed_not_due.update!(next_fetch_at: 1.hour.from_now)

    due_feeds = Feed.due_for_fetch
    assert_includes due_feeds, feed_due
    assert_not_includes due_feeds, feed_not_due
  end

  test "due_for_fetch scope should not return feeds with nil next_fetch_at" do
    feed = feeds(:ruby_blog)
    feed.update!(next_fetch_at: nil)

    assert_not_includes Feed.due_for_fetch, feed
  end

  test "record_successful_fetch! uses custom fetch_interval_minutes for next_fetch_at" do
    feed = feeds(:ruby_blog)
    feed.update!(fetch_interval_minutes: 180)

    travel_to Time.zone.parse("2025-02-10 10:00:00") do
      feed.record_successful_fetch!
      assert_equal Time.zone.parse("2025-02-10 13:00:00"), feed.next_fetch_at
    end
  end

  test "record_fetch_error! uses ERROR_BACKOFF_MINUTES regardless of fetch_interval_minutes" do
    feed = feeds(:ruby_blog)
    feed.update!(fetch_interval_minutes: 1440)

    travel_to Time.zone.parse("2025-02-10 10:00:00") do
      feed.record_fetch_error!("Test error")
      assert_equal Time.zone.parse("2025-02-10 10:30:00"), feed.next_fetch_at
      assert_equal "error", feed.status
    end
  end

  test "validates fetch_interval_minutes is in FETCH_INTERVAL_OPTIONS keys" do
    feed = Feed.new(url: "https://example.com/feed", fetch_interval_minutes: 999)
    assert_not feed.valid?
    assert_includes feed.errors[:fetch_interval_minutes], "は一覧にありません"
  end

  test "accepts all FETCH_INTERVAL_OPTIONS preset values" do
    Feed::FETCH_INTERVAL_OPTIONS.keys.each do |interval|
      feed = Feed.new(url: "https://example.com/feed#{interval}", fetch_interval_minutes: interval)
      feed.next_fetch_at = Time.current
      assert feed.valid?, "Expected #{interval} to be valid but got errors: #{feed.errors.full_messages}"
    end
  end

  test "changing fetch_interval_minutes recalculates next_fetch_at" do
    feed = feeds(:ruby_blog)

    travel_to Time.zone.parse("2025-02-10 10:00:00") do
      feed.update!(last_fetched_at: Time.zone.parse("2025-02-10 09:50:00"), next_fetch_at: Time.zone.parse("2025-02-10 10:00:00"))
      feed.update!(fetch_interval_minutes: 60)

      assert_equal Time.zone.parse("2025-02-10 10:50:00"), feed.reload.next_fetch_at
    end
  end

  test "changing fetch_interval_minutes without prior fetch sets next_fetch_at to now plus interval" do
    feed = Feed.create!(url: "https://example.com/new-feed.xml", next_fetch_at: Time.current)

    travel_to Time.zone.parse("2025-02-10 10:00:00") do
      feed.update!(fetch_interval_minutes: 180)

      assert_equal Time.zone.parse("2025-02-10 13:00:00"), feed.reload.next_fetch_at
    end
  end

  test "record_successful_fetch! should update feed with success status" do
    feed = feeds(:error_feed)
    feed.update!(
      status: :error,
      error_message: "Some error",
      last_fetched_at: 2.hours.ago,
      next_fetch_at: 1.hour.ago
    )

    feed.record_successful_fetch!(new_etag: "new-etag", new_last_modified: "Mon, 01 Jan 2024 00:00:00 GMT")

    feed.reload
    assert feed.ok?
    assert_nil feed.error_message
    assert_in_delta Time.current, feed.last_fetched_at, 2.seconds
    assert_in_delta 10.minutes.from_now, feed.next_fetch_at, 2.seconds
    assert_equal "new-etag", feed.etag
    assert_equal "Mon, 01 Jan 2024 00:00:00 GMT", feed.last_modified
  end

  test "record_successful_fetch! should preserve existing etag and last_modified if not provided" do
    feed = feeds(:ruby_blog)
    feed.update!(etag: "old-etag", last_modified: "Sun, 31 Dec 2023 00:00:00 GMT")

    feed.record_successful_fetch!

    feed.reload
    assert_equal "old-etag", feed.etag
    assert_equal "Sun, 31 Dec 2023 00:00:00 GMT", feed.last_modified
  end

  test "record_fetch_error! should update feed with error status" do
    feed = feeds(:ruby_blog)
    feed.update!(
      status: :ok,
      error_message: nil,
      last_fetched_at: 2.hours.ago,
      next_fetch_at: 1.hour.ago
    )

    feed.record_fetch_error!("Connection timeout")

    feed.reload
    assert feed.error?
    assert_equal "Connection timeout", feed.error_message
    assert_in_delta Time.current, feed.last_fetched_at, 2.seconds
    assert_in_delta 30.minutes.from_now, feed.next_fetch_at, 2.seconds
  end

  test "conditional_get_headers should return empty hash when no etag or last_modified" do
    feed = Feed.new(url: "https://example.com/feed.xml")
    assert_equal({}, feed.conditional_get_headers)
  end

  test "conditional_get_headers should return If-None-Match when etag present" do
    feed = Feed.new(url: "https://example.com/feed.xml", etag: "abc123")
    headers = feed.conditional_get_headers
    assert_equal "abc123", headers["If-None-Match"]
    assert_nil headers["If-Modified-Since"]
  end

  test "conditional_get_headers should return If-Modified-Since when last_modified present" do
    feed = Feed.new(url: "https://example.com/feed.xml", last_modified: "Mon, 01 Jan 2024 00:00:00 GMT")
    headers = feed.conditional_get_headers
    assert_nil headers["If-None-Match"]
    assert_equal "Mon, 01 Jan 2024 00:00:00 GMT", headers["If-Modified-Since"]
  end

  test "conditional_get_headers should return both headers when both present" do
    feed = Feed.new(
      url: "https://example.com/feed.xml",
      etag: "abc123",
      last_modified: "Mon, 01 Jan 2024 00:00:00 GMT"
    )
    headers = feed.conditional_get_headers
    assert_equal "abc123", headers["If-None-Match"]
    assert_equal "Mon, 01 Jan 2024 00:00:00 GMT", headers["If-Modified-Since"]
  end

  test "mark_all_entries_as_read! marks all unread entries as read" do
    feed = feeds(:ruby_blog)
    # ruby_article_two は未読（read_at: nil）
    assert feed.entries.unread.exists?

    count = feed.mark_all_entries_as_read!
    assert count > 0
    assert_not feed.entries.reload.unread.exists?
  end

  test "mark_all_entries_as_read! is idempotent" do
    feed = feeds(:ruby_blog)
    feed.mark_all_entries_as_read!

    count = feed.mark_all_entries_as_read!
    assert_equal 0, count
  end

  test "to_opml generates valid OPML 1.0 XML" do
    xml = Feed.to_opml
    doc = REXML::Document.new(xml)

    # Verify root element
    assert_equal "opml", doc.root.name
    assert_equal "1.0", doc.root.attributes["version"]

    # Verify head and body elements exist
    assert_not_nil REXML::XPath.first(doc, "//head")
    assert_not_nil REXML::XPath.first(doc, "//body")
    assert_not_nil REXML::XPath.first(doc, "//head/title")
  end

  test "to_opml includes feed attributes" do
    Feed.destroy_all
    feed = Feed.create!(
      url: "https://example.com/feed.xml",
      title: "Example Feed",
      site_url: "https://example.com/"
    )

    xml = Feed.to_opml
    doc = REXML::Document.new(xml)

    outline = REXML::XPath.first(doc, "//outline")
    assert_equal "rss", outline.attributes["type"]
    assert_equal "Example Feed", outline.attributes["text"]
    assert_equal "Example Feed", outline.attributes["title"]
    assert_equal "https://example.com/feed.xml", outline.attributes["xmlUrl"]
    assert_equal "https://example.com/", outline.attributes["htmlUrl"]
  end

  test "to_opml returns empty OPML when no feeds" do
    Feed.destroy_all

    xml = Feed.to_opml
    doc = REXML::Document.new(xml)

    outlines = REXML::XPath.match(doc, "//outline")
    assert_equal 0, outlines.size
  end

  test "to_opml orders feeds by title" do
    Feed.destroy_all
    Feed.create!(url: "https://z.com/feed", title: "Z Feed")
    Feed.create!(url: "https://a.com/feed", title: "A Feed")
    Feed.create!(url: "https://m.com/feed", title: "M Feed")

    xml = Feed.to_opml
    doc = REXML::Document.new(xml)

    titles = REXML::XPath.match(doc, "//outline").map { |o| o.attributes["title"] }
    assert_equal [ "A Feed", "M Feed", "Z Feed" ], titles
  end

  test "to_opml omits htmlUrl when site_url is blank" do
    Feed.destroy_all
    feed = Feed.create!(
      url: "https://example.com/feed.xml",
      title: "Example Feed",
      site_url: nil
    )

    xml = Feed.to_opml
    doc = REXML::Document.new(xml)

    outline = REXML::XPath.first(doc, "//outline")
    assert_nil outline.attributes["htmlUrl"]
    assert_equal "https://example.com/feed.xml", outline.attributes["xmlUrl"]
  end

  # -- Feed#fetch integration tests --

  test "fetch should successfully fetch and parse RSS 2.0 feed" do
    feed = feeds(:ruby_blog)
    feed.update!(url: "https://example.com/feed.xml", etag: nil, last_modified: nil, status: :ok, error_message: nil)

    rss_content = <<~RSS
      <?xml version="1.0"?>
      <rss version="2.0">
        <channel>
          <title>Example Feed</title>
          <link>https://example.com</link>
          <description>An example feed</description>
          <item>
            <guid>https://example.com/fetch-entry1</guid>
            <title>Entry 1</title>
            <link>https://example.com/fetch-entry1</link>
            <description>Entry 1 description</description>
            <pubDate>Mon, 01 Jan 2024 12:00:00 GMT</pubDate>
          </item>
          <item>
            <guid>https://example.com/fetch-entry2</guid>
            <title>Entry 2</title>
            <link>https://example.com/fetch-entry2</link>
            <description>Entry 2 description</description>
          </item>
        </channel>
      </rss>
    RSS

    stub_request(:get, "https://example.com/feed.xml")
      .to_return(status: 200, body: rss_content, headers: { "ETag" => "abc123", "Last-Modified" => "Wed, 03 Jan 2024 00:00:00 GMT" })

    assert_difference -> { feed.entries.count }, 2 do
      feed.fetch
    end

    feed.reload
    assert feed.ok?
    assert_nil feed.error_message
    assert_equal "abc123", feed.etag
    assert_equal "Wed, 03 Jan 2024 00:00:00 GMT", feed.last_modified
    assert_not_nil feed.last_fetched_at

    entry1 = feed.entries.find_by(guid: "https://example.com/fetch-entry1")
    assert_equal "Entry 1", entry1.title
    assert_equal "https://example.com/fetch-entry1", entry1.url
    assert_equal "Entry 1 description", entry1.body
  end

  test "fetch should successfully fetch and parse Atom feed" do
    feed = feeds(:ruby_blog)
    feed.update!(url: "https://example.com/feed.xml", etag: nil, last_modified: nil, status: :ok, error_message: nil)

    atom_content = <<~ATOM
      <?xml version="1.0"?>
      <feed xmlns="http://www.w3.org/2005/Atom">
        <title>Example Atom Feed</title>
        <link href="https://example.com"/>
        <entry>
          <id>https://example.com/atom-entry1</id>
          <title>Atom Entry 1</title>
          <link href="https://example.com/atom-entry1"/>
          <updated>2024-01-01T12:00:00Z</updated>
          <summary>Atom entry 1 summary</summary>
          <author><name>John Doe</name></author>
        </entry>
      </feed>
    ATOM

    stub_request(:get, "https://example.com/feed.xml")
      .to_return(status: 200, body: atom_content)

    assert_difference -> { feed.entries.count }, 1 do
      feed.fetch
    end

    entry = feed.entries.find_by(guid: "https://example.com/atom-entry1")
    assert_equal "Atom Entry 1", entry.title
    assert_equal "https://example.com/atom-entry1", entry.url
    assert_equal "Atom entry 1 summary", entry.body
    assert_equal "John Doe", entry.author
  end

  test "fetch should handle 304 Not Modified response" do
    feed = feeds(:ruby_blog)
    feed.update!(url: "https://example.com/feed.xml", etag: "abc123", last_modified: "Wed, 03 Jan 2024 00:00:00 GMT", status: :ok, error_message: nil)

    stub_request(:get, "https://example.com/feed.xml")
      .with(headers: { "If-None-Match" => "abc123", "If-Modified-Since" => "Wed, 03 Jan 2024 00:00:00 GMT" })
      .to_return(status: 304)

    assert_no_difference -> { feed.entries.count } do
      feed.fetch
    end

    feed.reload
    assert feed.ok?
    assert_not_nil feed.last_fetched_at
  end

  test "fetch should mark feed as error on HTTP error" do
    feed = feeds(:ruby_blog)
    feed.update!(url: "https://example.com/feed.xml", etag: nil, last_modified: nil, status: :ok, error_message: nil)

    stub_request(:get, "https://example.com/feed.xml")
      .to_return(status: 404, body: "Not Found")

    feed.fetch

    feed.reload
    assert feed.error?
    assert_match(/HTTP error 404/, feed.error_message)
    assert_not_nil feed.last_fetched_at
  end

  test "fetch should mark feed as error on timeout" do
    feed = feeds(:ruby_blog)
    feed.update!(url: "https://example.com/feed.xml", etag: nil, last_modified: nil, status: :ok, error_message: nil)

    stub_request(:get, "https://example.com/feed.xml").to_timeout

    feed.fetch

    feed.reload
    assert feed.error?
    assert_match(/timed out/, feed.error_message)
    assert_not_nil feed.last_fetched_at
  end

  test "fetch should mark feed as error on parse error" do
    feed = feeds(:ruby_blog)
    feed.update!(url: "https://example.com/feed.xml", etag: nil, last_modified: nil, status: :ok, error_message: nil)

    stub_request(:get, "https://example.com/feed.xml")
      .to_return(status: 200, body: "<invalid>not a valid feed</invalid>")

    feed.fetch

    feed.reload
    assert feed.error?
    assert_match(/format error/, feed.error_message)
    assert_not_nil feed.last_fetched_at
  end

  test "fetch should follow redirects" do
    feed = feeds(:ruby_blog)
    feed.update!(url: "https://example.com/feed.xml", etag: nil, last_modified: nil, status: :ok, error_message: nil)

    rss_content = <<~RSS
      <?xml version="1.0"?>
      <rss version="2.0">
        <channel>
          <title>Redirected Feed</title>
          <link>https://example.com</link>
          <item>
            <guid>https://example.com/redirected-entry</guid>
            <title>Redirected Entry</title>
            <link>https://example.com/redirected-entry</link>
            <description>Entry from redirected feed</description>
          </item>
        </channel>
      </rss>
    RSS

    stub_request(:get, "https://example.com/feed.xml")
      .to_return(status: 301, headers: { "Location" => "https://example.com/new-feed.xml" })
    stub_request(:get, "https://example.com/new-feed.xml")
      .to_return(status: 200, body: rss_content)

    assert_difference -> { feed.entries.count }, 1 do
      feed.fetch
    end

    entry = feed.entries.find_by(guid: "https://example.com/redirected-entry")
    assert_equal "Redirected Entry", entry.title
  end

  test "fetch should handle too many redirects" do
    feed = feeds(:ruby_blog)
    feed.update!(url: "https://example.com/feed.xml", etag: nil, last_modified: nil, status: :ok, error_message: nil)

    stub_request(:get, "https://example.com/feed.xml")
      .to_return(status: 301, headers: { "Location" => "https://example.com/r1" })
    stub_request(:get, "https://example.com/r1")
      .to_return(status: 301, headers: { "Location" => "https://example.com/r2" })
    stub_request(:get, "https://example.com/r2")
      .to_return(status: 301, headers: { "Location" => "https://example.com/r3" })
    stub_request(:get, "https://example.com/r3")
      .to_return(status: 301, headers: { "Location" => "https://example.com/r4" })
    stub_request(:get, "https://example.com/r4")
      .to_return(status: 301, headers: { "Location" => "https://example.com/r5" })
    stub_request(:get, "https://example.com/r5")
      .to_return(status: 301, headers: { "Location" => "https://example.com/r6" })

    feed.fetch

    feed.reload
    assert feed.error?
    assert_match(/Failed to fetch feed/, feed.error_message)
  end

  test "fetch should not create duplicate entries" do
    feed = feeds(:ruby_blog)
    feed.update!(url: "https://example.com/feed.xml", etag: nil, last_modified: nil, status: :ok, error_message: nil)

    feed.entries.create!(guid: "existing-guid", title: "Existing Entry", url: "https://example.com/old", body: "Old body")

    rss_content = <<~RSS
      <?xml version="1.0"?>
      <rss version="2.0">
        <channel>
          <title>Example Feed</title>
          <item>
            <guid>existing-guid</guid>
            <title>New Title</title>
            <link>https://example.com/entry</link>
            <description>New description</description>
          </item>
        </channel>
      </rss>
    RSS

    stub_request(:get, "https://example.com/feed.xml")
      .to_return(status: 200, body: rss_content)

    assert_no_difference -> { feed.entries.count } do
      feed.fetch
    end

    entry = feed.entries.find_by(guid: "existing-guid")
    assert_equal "Existing Entry", entry.title
    assert_equal "Old body", entry.body
  end

  test "fetch should send conditional GET headers when etag present" do
    feed = feeds(:ruby_blog)
    feed.update!(url: "https://example.com/feed.xml", etag: "test-etag", last_modified: nil, status: :ok, error_message: nil)

    stub_request(:get, "https://example.com/feed.xml")
      .with(headers: { "If-None-Match" => "test-etag" })
      .to_return(status: 304)

    feed.fetch

    assert_requested :get, "https://example.com/feed.xml",
                    headers: { "If-None-Match" => "test-etag" }, times: 1
  end

  test "fetch should send conditional GET headers when last_modified present" do
    feed = feeds(:ruby_blog)
    feed.update!(url: "https://example.com/feed.xml", etag: nil, last_modified: "Wed, 03 Jan 2024 00:00:00 GMT", status: :ok, error_message: nil)

    stub_request(:get, "https://example.com/feed.xml")
      .with(headers: { "If-Modified-Since" => "Wed, 03 Jan 2024 00:00:00 GMT" })
      .to_return(status: 304)

    feed.fetch

    assert_requested :get, "https://example.com/feed.xml",
                    headers: { "If-Modified-Since" => "Wed, 03 Jan 2024 00:00:00 GMT" }, times: 1
  end

  test "fetch should reject private network URLs" do
    feed = feeds(:ruby_blog)
    feed.update_column(:url, "http://127.0.0.1/feed.xml")

    feed.fetch

    feed.reload
    assert feed.error?
    assert_match(/Failed to fetch feed/, feed.error_message)
  end

  test "fetch should reject redirect to private network" do
    feed = feeds(:ruby_blog)
    feed.update!(url: "https://example.com/feed.xml", etag: nil, last_modified: nil, status: :ok, error_message: nil)

    stub_request(:get, "https://example.com/feed.xml")
      .to_return(status: 301, headers: { "Location" => "http://169.254.169.254/latest/meta-data/" })

    feed.fetch

    feed.reload
    assert feed.error?
  end

  test "fetch should reject responses that are too large" do
    feed = feeds(:ruby_blog)
    feed.update!(url: "https://example.com/feed.xml", etag: nil, last_modified: nil, status: :ok, error_message: nil)

    large_body = "x" * (11 * 1024 * 1024)
    stub_request(:get, "https://example.com/feed.xml")
      .to_return(status: 200, body: large_body)

    feed.fetch

    feed.reload
    assert feed.error?
    assert_match(/Failed to fetch feed/, feed.error_message)
  end

  test "fetch should send User-Agent header" do
    feed = feeds(:ruby_blog)
    feed.update!(url: "https://example.com/feed.xml", etag: nil, last_modified: nil, status: :ok, error_message: nil)

    stub_request(:get, "https://example.com/feed.xml")
      .to_return(status: 200, body: minimal_rss)

    feed.fetch

    assert_requested :get, "https://example.com/feed.xml",
                    headers: { "User-Agent" => "Tsubame/1.0" }, times: 1
  end

  test "fetch should handle relative URL redirects" do
    feed = feeds(:ruby_blog)
    feed.update!(url: "https://example.com/feed.xml", etag: nil, last_modified: nil, status: :ok, error_message: nil)

    stub_request(:get, "https://example.com/feed.xml")
      .to_return(status: 301, headers: { "Location" => "/new-feed.xml" })
    stub_request(:get, "https://example.com/new-feed.xml")
      .to_return(status: 200, body: minimal_rss)

    feed.fetch

    feed.reload
    assert feed.ok?
  end

  test "fetch should handle EUC-JP feed without Content-Type charset" do
    feed = feeds(:ruby_blog)
    feed.update!(url: "https://example.com/feed.xml", etag: nil, last_modified: nil, status: :ok, error_message: nil)

    eucjp_rss = <<~RSS.encode("EUC-JP")
      <?xml version="1.0" encoding="EUC-JP"?>
      <rss version="2.0">
        <channel>
          <title>日本語フィード</title>
          <link>https://example.com</link>
          <item>
            <guid>https://example.com/eucjp1</guid>
            <title>日本語エントリー</title>
            <link>https://example.com/eucjp1</link>
            <description>日本語の本文です</description>
          </item>
        </channel>
      </rss>
    RSS

    stub_request(:get, "https://example.com/feed.xml")
      .to_return(status: 200, body: eucjp_rss, headers: { "Content-Type" => "application/xml" })

    assert_difference -> { feed.entries.count }, 1 do
      feed.fetch
    end

    entry = feed.entries.last
    assert_equal "日本語エントリー", entry.title
    assert_equal "日本語の本文です", entry.body
  end

  test "fetch should handle Shift_JIS feed without Content-Type charset" do
    feed = feeds(:ruby_blog)
    feed.update!(url: "https://example.com/feed.xml", etag: nil, last_modified: nil, status: :ok, error_message: nil)

    sjis_rss = <<~RSS.encode("Shift_JIS")
      <?xml version="1.0" encoding="Shift_JIS"?>
      <rss version="2.0">
        <channel>
          <title>Shift_JISフィード</title>
          <link>https://example.com</link>
          <item>
            <guid>https://example.com/sjis1</guid>
            <title>シフトJISの記事</title>
            <link>https://example.com/sjis1</link>
            <description>本文テスト</description>
          </item>
        </channel>
      </rss>
    RSS

    stub_request(:get, "https://example.com/feed.xml")
      .to_return(status: 200, body: sjis_rss, headers: { "Content-Type" => "application/rss+xml" })

    assert_difference -> { feed.entries.count }, 1 do
      feed.fetch
    end

    entry = feed.entries.last
    assert_equal "シフトJISの記事", entry.title
    assert_equal "本文テスト", entry.body
  end

  test "fetch should handle RSS 1.0 (RDF) with content:encoded" do
    feed = feeds(:ruby_blog)
    feed.update!(url: "https://example.com/feed.xml", etag: nil, last_modified: nil, status: :ok, error_message: nil)

    rdf_content = <<~RDF
      <?xml version="1.0" encoding="UTF-8"?>
      <rdf:RDF
        xmlns:rdf="http://www.w3.org/1999/02/22-rdf-syntax-ns#"
        xmlns="http://purl.org/rss/1.0/"
        xmlns:content="http://purl.org/rss/1.0/modules/content/"
        xmlns:dc="http://purl.org/dc/elements/1.1/">
        <channel rdf:about="https://example.com">
          <title>RDF Feed</title>
          <link>https://example.com</link>
          <items><rdf:Seq><rdf:li rdf:resource="https://example.com/rdf-entry1"/></rdf:Seq></items>
        </channel>
        <item rdf:about="https://example.com/rdf-entry1">
          <title>RDF Entry</title>
          <link>https://example.com/rdf-entry1</link>
          <description>Short summary</description>
          <content:encoded><![CDATA[<p>Full HTML content with <strong>markup</strong></p>]]></content:encoded>
          <dc:creator>Author Name</dc:creator>
          <dc:date>2024-01-01T12:00:00+00:00</dc:date>
        </item>
      </rdf:RDF>
    RDF

    stub_request(:get, "https://example.com/feed.xml")
      .to_return(status: 200, body: rdf_content)

    assert_difference -> { feed.entries.count }, 1 do
      feed.fetch
    end

    feed.reload
    assert_equal "RDF Feed", feed.title

    entry = feed.entries.last
    assert_equal "RDF Entry", entry.title
    assert_equal "https://example.com/rdf-entry1", entry.url
    assert_equal "Author Name", entry.author
    assert_match "<p>Full HTML content", entry.body
    assert_match "<strong>markup</strong>", entry.body
    assert_no_match(/Short summary/, entry.body)
  end

  test "fetch should prefer content:encoded over description in RSS 2.0" do
    feed = feeds(:ruby_blog)
    feed.update!(url: "https://example.com/feed.xml", etag: nil, last_modified: nil, status: :ok, error_message: nil)

    rss_content = <<~RSS
      <?xml version="1.0"?>
      <rss version="2.0" xmlns:content="http://purl.org/rss/1.0/modules/content/">
        <channel>
          <title>Feed with content:encoded</title>
          <item>
            <guid>https://example.com/ce1</guid>
            <title>Entry with both</title>
            <description>Short summary only</description>
            <content:encoded><![CDATA[<p>Full article body</p>]]></content:encoded>
          </item>
        </channel>
      </rss>
    RSS

    stub_request(:get, "https://example.com/feed.xml")
      .to_return(status: 200, body: rss_content)

    assert_difference -> { feed.entries.count }, 1 do
      feed.fetch
    end

    entry = feed.entries.last
    assert_match "Full article body", entry.body
    assert_no_match(/Short summary/, entry.body)
  end

  test "exported OPML can be re-imported" do
    Feed.destroy_all
    original_feeds = [
      Feed.create!(url: "https://a.com/feed", title: "Feed A", site_url: "https://a.com/"),
      Feed.create!(url: "https://b.com/feed", title: "Feed B", site_url: "https://b.com/"),
      Feed.create!(url: "https://c.com/feed", title: "Feed C")
    ]

    # Export
    xml = Feed.to_opml

    # Clear and re-import
    Feed.destroy_all
    result = Feed.import_from_opml(xml)

    assert_equal 3, result[:added]
    assert_equal 0, result[:skipped]

    # Verify feeds match
    reimported = Feed.all.order(:url)
    assert_equal 3, reimported.size
    assert_equal "https://a.com/feed", reimported[0].url
    assert_equal "Feed A", reimported[0].title
    assert_equal "https://a.com/", reimported[0].site_url
  end

  private

  def minimal_rss
    <<~RSS
      <?xml version="1.0"?>
      <rss version="2.0">
        <channel>
          <title>Minimal Feed</title>
          <link>https://example.com</link>
          <description>A minimal feed</description>
        </channel>
      </rss>
    RSS
  end

  # -- Scope tests: with_unread_count / with_unreads --

  test "with_unread_count calculates unread count for each feed" do
    feeds = Feed.with_unread_count.order(:title)

    error_feed = feeds.find { |f| f.id == feeds(:error_feed).id }
    rails_news = feeds.find { |f| f.id == feeds(:rails_news).id }
    ruby_blog = feeds.find { |f| f.id == feeds(:ruby_blog).id }

    assert_equal 0, error_feed.unread_count
    assert_equal 1, rails_news.unread_count
    assert_equal 1, ruby_blog.unread_count
  end

  test "with_unreads returns only feeds with unread entries" do
    feed_ids = Feed.with_unreads.pluck(:id)

    assert_includes feed_ids, feeds(:ruby_blog).id
    assert_includes feed_ids, feeds(:rails_news).id
    assert_not_includes feed_ids, feeds(:error_feed).id
  end

  test "with_unreads returns empty when all entries are read" do
    Entry.update_all(read_at: Time.current)

    assert_empty Feed.with_unreads.to_a
  end

  test "unread_count returns 0 when scope not used" do
    feed = Feed.find(feeds(:ruby_blog).id)
    assert_equal 0, feed.unread_count
  end
end
