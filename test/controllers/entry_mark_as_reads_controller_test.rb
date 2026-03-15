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
    # ruby_article_two has a UserEntryState with pinned:true but no read_at
    state = @user.user_entry_states.find_by(entry: @entry)
    assert_nil state&.read_at

    post entry_mark_as_read_path(@entry)
    assert_response :success

    json = JSON.parse(response.body)
    assert json["success"]
    assert json["was_unread"]
    state = @user.user_entry_states.find_by(entry: @entry)
    assert_not_nil state.read_at
  end

  test "create returns not found for missing entry" do
    sign_in_as(@user)
    post entry_mark_as_read_path(entry_id: 99999)
    assert_response :not_found
  end

  test "create is idempotent" do
    sign_in_as(@user)
    @user.mark_entry_as_read!(@entry)

    post entry_mark_as_read_path(@entry)
    assert_response :success

    json = JSON.parse(response.body)
    assert json["success"]
    assert_not json["was_unread"]
  end
end
