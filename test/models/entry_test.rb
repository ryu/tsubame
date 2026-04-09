require "test_helper"
require "rss"

class EntryTest < ActiveSupport::TestCase
  test "should be valid with required attributes" do
    entry = Entry.new(
      feed: feeds(:ruby_blog),
      guid: "https://example.com/new"
    )
    assert entry.valid?
  end

  test "should require guid" do
    entry = Entry.new(feed: feeds(:ruby_blog), guid: nil)
    assert_not entry.valid?
    assert_includes entry.errors[:guid], "を入力してください"
  end

  test "should require feed" do
    entry = Entry.new(guid: "https://example.com/test")
    assert_not entry.valid?
    assert_includes entry.errors[:feed], "を入力してください"
  end

  test "should enforce unique guid within feed scope" do
    existing = entries(:ruby_article_one)
    entry = Entry.new(
      feed: existing.feed,
      guid: existing.guid
    )
    assert_not entry.valid?
    assert_includes entry.errors[:guid], "はすでに存在します"
  end

  test "should allow same guid in different feeds" do
    entry = Entry.new(
      feed: feeds(:rails_news),
      guid: entries(:ruby_article_one).guid
    )
    assert entry.valid?
  end

  test "recently_published scope should order by published_at desc" do
    recent = Entry.recently_published.to_a
    assert_equal entries(:rails_article_one), recent.first
    assert_equal entries(:ruby_article_one), recent.last
  end

  test "should belong to feed" do
    entry = entries(:ruby_article_one)
    assert_equal feeds(:ruby_blog), entry.feed
  end

  test "safe_url_for_link returns url for valid http url" do
    entry = entries(:ruby_article_one)
    assert_equal entry.url, entry.safe_url_for_link
  end

  test "safe_url_for_link returns nil for invalid url" do
    entry = Entry.new(
      feed: feeds(:ruby_blog),
      guid: "test",
      url: "javascript:alert('xss')"
    )
    assert_nil entry.safe_url_for_link
  end

  test "safe_url_for_link returns nil for blank url" do
    entry = Entry.new(
      feed: feeds(:ruby_blog),
      guid: "test",
      url: nil
    )
    assert_nil entry.safe_url_for_link
  end

  # -- attributes_from_rss_item tests --

  test "attributes_from_rss_item extracts RSS 2.0 item" do
    parsed = RSS::Parser.parse(<<~RSS, false)
      <?xml version="1.0"?>
      <rss version="2.0">
        <channel>
          <title>Test</title>
          <item>
            <guid>https://example.com/1</guid>
            <title>Title One</title>
            <link>https://example.com/1</link>
            <description>Body text</description>
            <pubDate>Mon, 01 Jan 2024 12:00:00 GMT</pubDate>
          </item>
        </channel>
      </rss>
    RSS

    attrs = Entry.attributes_from_rss_item(parsed.items.first)
    assert_equal "https://example.com/1", attrs[:guid]
    assert_equal "Title One", attrs[:title]
    assert_equal "https://example.com/1", attrs[:url]
    assert_equal "Body text", attrs[:body]
    assert_not_nil attrs[:published_at]
  end

  test "attributes_from_rss_item extracts Atom entry" do
    parsed = RSS::Parser.parse(<<~ATOM, false)
      <?xml version="1.0"?>
      <feed xmlns="http://www.w3.org/2005/Atom">
        <title>Test</title>
        <entry>
          <id>urn:atom:1</id>
          <title>Atom Title</title>
          <link href="https://example.com/atom1"/>
          <summary>Summary text</summary>
          <author><name>Alice</name></author>
          <updated>2024-01-01T12:00:00Z</updated>
        </entry>
      </feed>
    ATOM

    attrs = Entry.attributes_from_rss_item(parsed.items.first)
    assert_equal "urn:atom:1", attrs[:guid]
    assert_equal "Atom Title", attrs[:title]
    assert_equal "https://example.com/atom1", attrs[:url]
    assert_equal "Summary text", attrs[:body]
    assert_equal "Alice", attrs[:author]
  end

  test "attributes_from_rss_item extracts RDF (RSS 1.0) item" do
    parsed = RSS::Parser.parse(<<~RDF, false)
      <?xml version="1.0"?>
      <rdf:RDF
        xmlns:rdf="http://www.w3.org/1999/02/22-rdf-syntax-ns#"
        xmlns="http://purl.org/rss/1.0/"
        xmlns:dc="http://purl.org/dc/elements/1.1/"
        xmlns:content="http://purl.org/rss/1.0/modules/content/">
        <channel rdf:about="https://example.com">
          <title>RDF Feed</title>
          <link>https://example.com</link>
          <items><rdf:Seq><rdf:li rdf:resource="https://example.com/rdf1"/></rdf:Seq></items>
        </channel>
        <item rdf:about="https://example.com/rdf1">
          <title>RDF Title</title>
          <link>https://example.com/rdf1</link>
          <dc:creator>Bob</dc:creator>
          <content:encoded><![CDATA[<p>Full body</p>]]></content:encoded>
        </item>
      </rdf:RDF>
    RDF

    attrs = Entry.attributes_from_rss_item(parsed.items.first)
    assert_equal "https://example.com/rdf1", attrs[:guid]
    assert_equal "RDF Title", attrs[:title]
    assert_equal "Bob", attrs[:author]
    assert_match "<p>Full body</p>", attrs[:body]
  end

  test "attributes_from_rss_item prefers content:encoded over description" do
    parsed = RSS::Parser.parse(<<~RSS, false)
      <?xml version="1.0"?>
      <rss version="2.0" xmlns:content="http://purl.org/rss/1.0/modules/content/">
        <channel>
          <title>Test</title>
          <item>
            <guid>g1</guid>
            <title>T</title>
            <description>Short</description>
            <content:encoded><![CDATA[<p>Full article</p>]]></content:encoded>
          </item>
        </channel>
      </rss>
    RSS

    attrs = Entry.attributes_from_rss_item(parsed.items.first)
    assert_match "Full article", attrs[:body]
    assert_no_match(/Short/, attrs[:body])
  end

  test "attributes_from_rss_item returns nil when guid is blank" do
    parsed = RSS::Parser.parse(<<~RSS, false)
      <?xml version="1.0"?>
      <rss version="2.0">
        <channel>
          <title>Test</title>
          <item>
            <title>No GUID</title>
            <description>No guid here</description>
          </item>
        </channel>
      </rss>
    RSS

    attrs = Entry.attributes_from_rss_item(parsed.items.first)
    assert_nil attrs
  end

  # -- normalize_url tests --

  test "normalize_url removes utm parameters" do
    assert_equal "https://example.com/post?id=1",
      Entry.normalize_url("https://example.com/post?utm_source=twitter&id=1")
  end

  test "normalize_url removes fbclid and gclid" do
    assert_equal "https://example.com/post",
      Entry.normalize_url("https://example.com/post?fbclid=abc&gclid=def")
  end

  test "normalize_url removes fragment" do
    assert_equal "https://example.com/post",
      Entry.normalize_url("https://example.com/post#section1")
  end

  test "normalize_url removes trailing slash" do
    assert_equal "https://example.com/post",
      Entry.normalize_url("https://example.com/post/")
  end

  test "normalize_url preserves root path slash" do
    assert_equal "https://example.com/",
      Entry.normalize_url("https://example.com/")
  end

  test "normalize_url preserves scheme difference" do
    assert_not_equal Entry.normalize_url("http://example.com/post"),
      Entry.normalize_url("https://example.com/post")
  end

  test "normalize_url returns nil for blank" do
    assert_nil Entry.normalize_url(nil)
    assert_nil Entry.normalize_url("")
  end

  test "normalize_url returns nil for non-HTTP" do
    assert_nil Entry.normalize_url("ftp://example.com/file")
  end

  test "normalize_url returns nil for invalid URI" do
    assert_nil Entry.normalize_url("ht tp://bad url")
  end

  # -- before_save callback tests --

  test "sets content_url on create" do
    entry = Entry.create!(
      feed: feeds(:ruby_blog),
      guid: "new-entry-1",
      url: "https://example.com/new?utm_source=rss"
    )
    assert_equal "https://example.com/new", entry.content_url
  end

  test "updates content_url when url changes" do
    entry = entries(:ruby_article_one)
    entry.update!(url: "https://example.com/updated")
    assert_equal "https://example.com/updated", entry.content_url
  end

  test "sets content_url to nil for non-HTTP url" do
    entry = Entry.create!(
      feed: feeds(:ruby_blog),
      guid: "new-entry-2",
      url: "javascript:alert(1)"
    )
    assert_nil entry.content_url
  end

  # -- duplicates_of scope tests --

  test "duplicates_of returns entries with same content_url" do
    entry = entries(:ruby_article_one)
    entry.update_column(:content_url, "https://example.com/ruby/1")

    dup = entries(:aggregator_ruby_one)
    dup.update_column(:content_url, "https://example.com/ruby/1")

    duplicates = Entry.duplicates_of(entry)
    assert_includes duplicates, dup
    assert_not_includes duplicates, entry
  end

  test "duplicates_of returns none when content_url is blank" do
    entry = Entry.new(content_url: nil)
    assert_empty Entry.duplicates_of(entry)
  end

  test "attributes_from_rss_item strips HTML from title" do
    parsed = RSS::Parser.parse(<<~RSS, false)
      <?xml version="1.0"?>
      <rss version="2.0">
        <channel>
          <title>Test</title>
          <item>
            <guid>g1</guid>
            <title><![CDATA[<b>Bold</b> title]]></title>
            <description>Body</description>
          </item>
        </channel>
      </rss>
    RSS

    attrs = Entry.attributes_from_rss_item(parsed.items.first)
    assert_equal "Bold title", attrs[:title]
  end
end
