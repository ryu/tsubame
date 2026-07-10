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

  test "create pins entry" do
    sign_in_as(@user)
    @user.user_entry_states.where(entry: @entry).update_all(pinned: false)

    post entry_pin_path(@entry), as: :turbo_stream
    assert_response :success
    assert @user.entry_pinned?(@entry)
  end

  test "create is idempotent" do
    sign_in_as(@user)
    @user.pin_entry!(@entry)

    post entry_pin_path(@entry), as: :turbo_stream
    assert_response :success
    assert @user.entry_pinned?(@entry)
  end

  test "destroy unpins entry" do
    sign_in_as(@user)
    @user.pin_entry!(@entry)

    delete entry_pin_path(@entry), as: :turbo_stream
    assert_response :success
    assert_not @user.entry_pinned?(@entry)
  end

  test "create returns turbo stream" do
    sign_in_as(@user)
    post entry_pin_path(@entry), as: :turbo_stream
    assert_response :success
    assert_equal "text/vnd.turbo-stream.html", response.media_type
  end
end
