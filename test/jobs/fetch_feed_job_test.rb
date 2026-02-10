require "test_helper"

class FetchFeedJobTest < ActiveJob::TestCase
  setup do
    @feed = feeds(:ruby_blog)
    @feed.update!(
      url: "https://example.com/feed.xml",
      etag: nil,
      last_modified: nil,
      status: :ok,
      error_message: nil
    )
  end

  test "should successfully fetch and parse RSS 2.0 feed" do
    rss_content = <<~RSS
      <?xml version="1.0"?>
      <rss version="2.0">
        <channel>
          <title>Example Feed</title>
          <link>https://example.com</link>
          <description>An example feed</description>
          <item>
            <guid>https://example.com/entry1</guid>
            <title>Entry 1</title>
            <link>https://example.com/entry1</link>
            <description>Entry 1 description</description>
            <pubDate>Mon, 01 Jan 2024 12:00:00 GMT</pubDate>
          </item>
          <item>
            <guid>https://example.com/entry2</guid>
            <title>Entry 2</title>
            <link>https://example.com/entry2</link>
            <description>Entry 2 description</description>
            <pubDate>Tue, 02 Jan 2024 12:00:00 GMT</pubDate>
          </item>
        </channel>
      </rss>
    RSS

    stub_request(:get, "https://example.com/feed.xml")
      .to_return(
        status: 200,
        body: rss_content,
        headers: { "ETag" => "abc123", "Last-Modified" => "Wed, 03 Jan 2024 00:00:00 GMT" }
      )

    assert_difference -> { @feed.entries.count }, 2 do
      FetchFeedJob.perform_now(@feed.id)
    end

    @feed.reload
    assert @feed.ok?
    assert_nil @feed.error_message
    assert_equal "abc123", @feed.etag
    assert_equal "Wed, 03 Jan 2024 00:00:00 GMT", @feed.last_modified
    assert_not_nil @feed.last_fetched_at
    assert_not_nil @feed.next_fetch_at

    entry1 = @feed.entries.find_by(guid: "https://example.com/entry1")
    assert_equal "Entry 1", entry1.title
    assert_equal "https://example.com/entry1", entry1.url
    assert_equal "Entry 1 description", entry1.body
  end

  test "should successfully fetch and parse Atom feed" do
    atom_content = <<~ATOM
      <?xml version="1.0"?>
      <feed xmlns="http://www.w3.org/2005/Atom">
        <title>Example Atom Feed</title>
        <link href="https://example.com"/>
        <updated>2024-01-03T00:00:00Z</updated>
        <entry>
          <id>https://example.com/atom-entry1</id>
          <title>Atom Entry 1</title>
          <link href="https://example.com/atom-entry1"/>
          <updated>2024-01-01T12:00:00Z</updated>
          <summary>Atom entry 1 summary</summary>
          <author>
            <name>John Doe</name>
          </author>
        </entry>
      </feed>
    ATOM

    stub_request(:get, "https://example.com/feed.xml")
      .to_return(status: 200, body: atom_content)

    assert_difference -> { @feed.entries.count }, 1 do
      FetchFeedJob.perform_now(@feed.id)
    end

    entry = @feed.entries.find_by(guid: "https://example.com/atom-entry1")
    assert_equal "Atom Entry 1", entry.title
    assert_equal "https://example.com/atom-entry1", entry.url
    assert_equal "Atom entry 1 summary", entry.body
    assert_equal "John Doe", entry.author
  end

  test "should handle 304 Not Modified response" do
    @feed.update!(etag: "abc123", last_modified: "Wed, 03 Jan 2024 00:00:00 GMT")

    stub_request(:get, "https://example.com/feed.xml")
      .with(headers: { "If-None-Match" => "abc123", "If-Modified-Since" => "Wed, 03 Jan 2024 00:00:00 GMT" })
      .to_return(status: 304)

    assert_no_difference -> { @feed.entries.count } do
      FetchFeedJob.perform_now(@feed.id)
    end

    @feed.reload
    assert @feed.ok?
    assert_not_nil @feed.last_fetched_at
  end

  test "should mark feed as error on HTTP error" do
    stub_request(:get, "https://example.com/feed.xml")
      .to_return(status: 404, body: "Not Found")

    FetchFeedJob.perform_now(@feed.id)

    @feed.reload
    assert @feed.error?
    assert_match(/HTTP error 404/, @feed.error_message)
    assert_not_nil @feed.last_fetched_at
  end

  test "should mark feed as error on timeout" do
    stub_request(:get, "https://example.com/feed.xml")
      .to_timeout

    FetchFeedJob.perform_now(@feed.id)

    @feed.reload
    assert @feed.error?
    assert_match(/timed out/, @feed.error_message)
    assert_not_nil @feed.last_fetched_at
  end

  test "should mark feed as error on parse error" do
    stub_request(:get, "https://example.com/feed.xml")
      .to_return(status: 200, body: "<invalid>not a valid feed</invalid>")

    FetchFeedJob.perform_now(@feed.id)

    @feed.reload
    assert @feed.error?
    assert_match(/format error/, @feed.error_message)
    assert_not_nil @feed.last_fetched_at
  end

  test "should follow redirects" do
    rss_content = <<~RSS
      <?xml version="1.0"?>
      <rss version="2.0">
        <channel>
          <title>Redirected Feed</title>
          <link>https://example.com</link>
          <description>An example feed</description>
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

    assert_difference -> { @feed.entries.count }, 1 do
      FetchFeedJob.perform_now(@feed.id)
    end

    entry = @feed.entries.find_by(guid: "https://example.com/redirected-entry")
    assert_equal "Redirected Entry", entry.title
  end

  test "should handle too many redirects" do
    stub_request(:get, "https://example.com/feed.xml")
      .to_return(status: 301, headers: { "Location" => "https://example.com/redirect1" })

    stub_request(:get, "https://example.com/redirect1")
      .to_return(status: 301, headers: { "Location" => "https://example.com/redirect2" })

    stub_request(:get, "https://example.com/redirect2")
      .to_return(status: 301, headers: { "Location" => "https://example.com/redirect3" })

    stub_request(:get, "https://example.com/redirect3")
      .to_return(status: 301, headers: { "Location" => "https://example.com/redirect4" })

    stub_request(:get, "https://example.com/redirect4")
      .to_return(status: 301, headers: { "Location" => "https://example.com/redirect5" })

    stub_request(:get, "https://example.com/redirect5")
      .to_return(status: 301, headers: { "Location" => "https://example.com/redirect6" })

    FetchFeedJob.perform_now(@feed.id)

    @feed.reload
    assert @feed.error?
    assert_match(/Failed to fetch feed/, @feed.error_message)
  end

  test "should not create duplicate entries" do
    rss_content = <<~RSS
      <?xml version="1.0"?>
      <rss version="2.0">
        <channel>
          <title>Example Feed</title>
          <link>https://example.com</link>
          <description>An example feed</description>
          <item>
            <guid>existing-guid</guid>
            <title>New Entry Title</title>
            <link>https://example.com/entry</link>
            <description>New description</description>
          </item>
        </channel>
      </rss>
    RSS

    # Create existing entry with same guid
    @feed.entries.create!(
      guid: "existing-guid",
      title: "Existing Entry",
      url: "https://example.com/old",
      body: "Old body"
    )

    stub_request(:get, "https://example.com/feed.xml")
      .to_return(status: 200, body: rss_content)

    assert_no_difference -> { @feed.entries.count } do
      FetchFeedJob.perform_now(@feed.id)
    end

    # Existing entry should remain unchanged
    entry = @feed.entries.find_by(guid: "existing-guid")
    assert_equal "Existing Entry", entry.title
    assert_equal "Old body", entry.body
  end

  test "should handle feed not found" do
    assert_nothing_raised do
      FetchFeedJob.perform_now(999999)
    end
  end

  test "should send conditional GET headers when etag present" do
    @feed.update!(etag: "test-etag")

    stub_request(:get, "https://example.com/feed.xml")
      .with(headers: { "If-None-Match" => "test-etag" })
      .to_return(status: 304)

    FetchFeedJob.perform_now(@feed.id)

    assert_requested :get, "https://example.com/feed.xml",
                    headers: { "If-None-Match" => "test-etag" },
                    times: 1
  end

  test "should send conditional GET headers when last_modified present" do
    @feed.update!(last_modified: "Wed, 03 Jan 2024 00:00:00 GMT")

    stub_request(:get, "https://example.com/feed.xml")
      .with(headers: { "If-Modified-Since" => "Wed, 03 Jan 2024 00:00:00 GMT" })
      .to_return(status: 304)

    FetchFeedJob.perform_now(@feed.id)

    assert_requested :get, "https://example.com/feed.xml",
                    headers: { "If-Modified-Since" => "Wed, 03 Jan 2024 00:00:00 GMT" },
                    times: 1
  end

  test "should reject private network URLs" do
    @feed.update_column(:url, "http://127.0.0.1/feed.xml")

    FetchFeedJob.perform_now(@feed.id)

    @feed.reload
    assert @feed.error?
    assert_match(/Failed to fetch feed/, @feed.error_message)
  end

  test "should reject redirect to private network" do
    stub_request(:get, "https://example.com/feed.xml")
      .to_return(status: 301, headers: { "Location" => "http://169.254.169.254/latest/meta-data/" })

    FetchFeedJob.perform_now(@feed.id)

    @feed.reload
    assert @feed.error?
  end

  test "should reject responses that are too large" do
    large_body = "x" * (11 * 1024 * 1024)

    stub_request(:get, "https://example.com/feed.xml")
      .to_return(status: 200, body: large_body)

    FetchFeedJob.perform_now(@feed.id)

    @feed.reload
    assert @feed.error?
    assert_match(/Failed to fetch feed/, @feed.error_message)
  end

  test "should handle relative URL redirects" do
    rss_content = minimal_rss

    stub_request(:get, "https://example.com/feed.xml")
      .to_return(status: 301, headers: { "Location" => "/new-feed.xml" })

    stub_request(:get, "https://example.com/new-feed.xml")
      .to_return(status: 200, body: rss_content)

    FetchFeedJob.perform_now(@feed.id)

    @feed.reload
    assert @feed.ok?
  end

  test "should send User-Agent header" do
    stub_request(:get, "https://example.com/feed.xml")
      .to_return(status: 200, body: minimal_rss)

    FetchFeedJob.perform_now(@feed.id)

    assert_requested :get, "https://example.com/feed.xml",
                    headers: { "User-Agent" => "Tsubame/1.0" },
                    times: 1
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
end
