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
end
