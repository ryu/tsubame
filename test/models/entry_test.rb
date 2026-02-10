require "test_helper"

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
    assert_includes entry.errors[:guid], "can't be blank"
  end

  test "should require feed" do
    entry = Entry.new(guid: "https://example.com/test")
    assert_not entry.valid?
    assert_includes entry.errors[:feed], "must exist"
  end

  test "should enforce unique guid within feed scope" do
    existing = entries(:ruby_article_one)
    entry = Entry.new(
      feed: existing.feed,
      guid: existing.guid
    )
    assert_not entry.valid?
    assert_includes entry.errors[:guid], "has already been taken"
  end

  test "should allow same guid in different feeds" do
    entry = Entry.new(
      feed: feeds(:rails_news),
      guid: entries(:ruby_article_one).guid
    )
    assert entry.valid?
  end

  test "should have pinned false by default" do
    entry = Entry.create!(
      feed: feeds(:ruby_blog),
      guid: "https://example.com/new"
    )
    assert_equal false, entry.pinned
  end

  test "unread scope should return entries without read_at" do
    unread = Entry.unread
    assert_includes unread, entries(:ruby_article_two)
    assert_includes unread, entries(:rails_article_one)
    assert_not_includes unread, entries(:ruby_article_one)
  end

  test "pinned scope should return pinned entries" do
    pinned = Entry.pinned
    assert_includes pinned, entries(:ruby_article_two)
    assert_not_includes pinned, entries(:ruby_article_one)
    assert_not_includes pinned, entries(:rails_article_one)
  end

  test "recent scope should order by published_at desc" do
    recent = Entry.recent.to_a
    assert_equal entries(:rails_article_one), recent.first
    assert_equal entries(:ruby_article_one), recent.last
  end

  test "should belong to feed" do
    entry = entries(:ruby_article_one)
    assert_equal feeds(:ruby_blog), entry.feed
  end
end
