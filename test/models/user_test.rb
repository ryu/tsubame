require "test_helper"

class UserTest < ActiveSupport::TestCase
  test "downcases and strips email_address" do
    user = User.new(email_address: " DOWNCASED@EXAMPLE.COM ")
    assert_equal("downcased@example.com", user.email_address)
  end

  # -- mark_entry_as_read! with duplicate sync tests --

  test "mark_entry_as_read syncs read state to duplicate entries" do
    user = users(:one)
    original = entries(:ruby_article_two)
    duplicate = entries(:aggregator_ruby_one)

    # Set same content_url to simulate duplicates
    original.update_column(:content_url, "https://example.com/ruby/2")
    duplicate.update_column(:content_url, "https://example.com/ruby/2")

    user.mark_entry_as_read!(original)

    dup_state = user.user_entry_states.find_by(entry: duplicate)
    assert_not_nil dup_state&.read_at, "Duplicate entry should be marked as read"
  end

  test "mark_entry_as_read does not overwrite pinned state on duplicate" do
    user = users(:one)
    original = entries(:ruby_article_one)
    duplicate = entries(:aggregator_ruby_one)

    original.update_column(:content_url, "https://example.com/shared")
    duplicate.update_column(:content_url, "https://example.com/shared")

    # Pin the duplicate first
    user.toggle_entry_pin!(duplicate)
    assert user.entry_pinned?(duplicate)

    # Clear read state so mark_entry_as_read! proceeds
    user.user_entry_states.where(entry: original).update_all(read_at: nil)
    user.mark_entry_as_read!(original)

    dup_state = user.user_entry_states.find_by(entry: duplicate)
    assert dup_state.pinned, "Pin state should be preserved on duplicate"
    assert_not_nil dup_state.read_at, "Duplicate should be marked as read"
  end

  test "mark_entry_as_read skips sync when content_url is blank" do
    user = users(:one)
    entry = entries(:ruby_article_two)
    entry.update_column(:content_url, nil)

    assert_nothing_raised do
      user.mark_entry_as_read!(entry)
    end
  end

  test "mark_feed_entries_as_read syncs read state to duplicates in other feeds" do
    user = users(:one)
    ruby_entry = entries(:ruby_article_two)
    aggregator_entry = entries(:aggregator_ruby_one)

    ruby_entry.update_column(:content_url, "https://example.com/ruby/2")
    aggregator_entry.update_column(:content_url, "https://example.com/ruby/2")

    user.mark_feed_entries_as_read!(feeds(:ruby_blog))

    dup_state = user.user_entry_states.find_by(entry: aggregator_entry)
    assert_not_nil dup_state&.read_at, "Duplicate in aggregator feed should be marked as read"
  end

  test "grouped_subscriptions_for_home returns folder groups with unread counts" do
    groups = users(:one).grouped_subscriptions_for_home(rate: 0)

    assert_kind_of FolderGroup, groups.first

    tech_group = groups.find { |group| group.folder == folders(:tech) }
    assert_not_nil tech_group
    assert_equal 2, tech_group.unread_count
    assert_equal [ subscriptions(:user_one_rails_news), subscriptions(:user_one_ruby_blog) ],
      tech_group.subscriptions
  end
end
