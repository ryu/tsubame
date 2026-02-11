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
    assert feed.entries.unread.exists?

    post feed_mark_as_read_path(feed)
    assert_response :success

    json = JSON.parse(response.body)
    assert json["success"]
    assert json["marked_count"] > 0
    assert_not feed.entries.reload.unread.exists?
  end
end
