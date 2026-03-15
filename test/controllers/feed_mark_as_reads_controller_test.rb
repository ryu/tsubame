require "test_helper"

class FeedMarkAsReadsControllerTest < ActionDispatch::IntegrationTest
  setup do
    @user = users(:one)
  end

  test "create requires authentication" do
    post feed_mark_as_read_path(feeds(:ruby_blog))
    assert_redirected_to new_session_path
  end

  test "create marks all entries as read" do
    sign_in_as(@user)
    feed = feeds(:ruby_blog)

    # Verify there are unread entries (entries without a read UserEntryState)
    unread_count = feed.entries.where.not(
      id: @user.user_entry_states.where.not(read_at: nil).select(:entry_id)
    ).count
    assert unread_count > 0

    post feed_mark_as_read_path(feed)
    assert_response :success

    json = JSON.parse(response.body)
    assert json["success"]
    assert json["marked_count"] > 0

    # All entries should now be read
    feed.entries.each do |entry|
      state = @user.user_entry_states.find_by(entry: entry)
      assert_not_nil state&.read_at, "Entry #{entry.title} should be marked as read"
    end
  end
end
