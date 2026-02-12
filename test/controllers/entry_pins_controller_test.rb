require "test_helper"

class EntryPinsControllerTest < ActionDispatch::IntegrationTest
  setup do
    @user = users(:one)
    @entry = entries(:ruby_article_two)
  end

  test "create requires authentication" do
    post entry_pin_path(@entry)
    assert_redirected_to new_session_path
  end

  test "create returns not found for missing entry" do
    sign_in_as(@user)
    post entry_pin_path(entry_id: 99999), as: :turbo_stream
    assert_response :not_found
  end

  test "create toggles pinned status" do
    sign_in_as(@user)
    original_pinned = @entry.pinned

    post entry_pin_path(@entry), as: :turbo_stream
    assert_response :success
    assert_equal !original_pinned, @entry.reload.pinned
  end

  test "create returns turbo stream" do
    sign_in_as(@user)
    post entry_pin_path(@entry), as: :turbo_stream
    assert_response :success
    assert_equal "text/vnd.turbo-stream.html", response.media_type
  end
end
