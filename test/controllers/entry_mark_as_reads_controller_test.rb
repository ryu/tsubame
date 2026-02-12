require "test_helper"

class EntryMarkAsReadsControllerTest < ActionDispatch::IntegrationTest
  setup do
    @user = users(:one)
    @entry = entries(:ruby_article_two)
  end

  test "create requires authentication" do
    post entry_mark_as_read_path(@entry)
    assert_redirected_to new_session_path
  end

  test "create marks entry as read" do
    sign_in_as(@user)
    assert_nil @entry.read_at

    post entry_mark_as_read_path(@entry)
    assert_response :success

    json = JSON.parse(response.body)
    assert json["success"]
    assert json["was_unread"]
    assert_not_nil @entry.reload.read_at
  end

  test "create returns not found for missing entry" do
    sign_in_as(@user)
    post entry_mark_as_read_path(entry_id: 99999)
    assert_response :not_found
  end

  test "create is idempotent" do
    sign_in_as(@user)
    @entry.mark_as_read!

    post entry_mark_as_read_path(@entry)
    assert_response :success

    json = JSON.parse(response.body)
    assert json["success"]
    assert_not json["was_unread"]
  end
end
