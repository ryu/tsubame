require "test_helper"

class FeedTest < ActiveSupport::TestCase
  test "should be valid with required attributes" do
    feed = Feed.new(url: "https://example.com/feed.xml")
    assert feed.valid?
  end

  test "should require url" do
    feed = Feed.new(url: nil)
    assert_not feed.valid?
    assert_includes feed.errors[:url], "can't be blank"
  end

  test "should enforce unique url" do
    existing = feeds(:ruby_blog)
    feed = Feed.new(url: existing.url)
    assert_not feed.valid?
    assert_includes feed.errors[:url], "has already been taken"
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

  test "import_from_opml should raise error for invalid XML" do
    invalid_xml = "<invalid>not closed"

    assert_raises(RuntimeError, match: /OPML/) do
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

  test "mark_as_fetched! should update feed with success status" do
    feed = feeds(:error_feed)
    feed.update!(
      status: :error,
      error_message: "Some error",
      last_fetched_at: 2.hours.ago,
      next_fetch_at: 1.hour.ago
    )

    feed.mark_as_fetched!(etag: "new-etag", last_modified: "Mon, 01 Jan 2024 00:00:00 GMT")

    feed.reload
    assert feed.ok?
    assert_nil feed.error_message
    assert_in_delta Time.current, feed.last_fetched_at, 2.seconds
    assert_in_delta 10.minutes.from_now, feed.next_fetch_at, 2.seconds
    assert_equal "new-etag", feed.etag
    assert_equal "Mon, 01 Jan 2024 00:00:00 GMT", feed.last_modified
  end

  test "mark_as_fetched! should preserve existing etag and last_modified if not provided" do
    feed = feeds(:ruby_blog)
    feed.update!(etag: "old-etag", last_modified: "Sun, 31 Dec 2023 00:00:00 GMT")

    feed.mark_as_fetched!

    feed.reload
    assert_equal "old-etag", feed.etag
    assert_equal "Sun, 31 Dec 2023 00:00:00 GMT", feed.last_modified
  end

  test "mark_as_error! should update feed with error status" do
    feed = feeds(:ruby_blog)
    feed.update!(
      status: :ok,
      error_message: nil,
      last_fetched_at: 2.hours.ago,
      next_fetch_at: 1.hour.ago
    )

    feed.mark_as_error!("Connection timeout")

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
end
