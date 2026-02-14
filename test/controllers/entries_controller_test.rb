require "test_helper"

class EntriesControllerTest < ActionDispatch::IntegrationTest
  setup do
    @user = users(:one)
    @feed = feeds(:ruby_blog)
    @entry = entries(:ruby_article_two)
  end

  test "index requires authentication" do
    get feed_entries_path(@feed)
    assert_redirected_to new_session_path
  end

  test "index shows entries for feed" do
    sign_in_as(@user)
    get feed_entries_path(@feed)
    assert_response :success
    assert_select "turbo-frame#entry_list"
    assert_select ".entry-item", minimum: 1
  end

  test "index is turbo frame compatible" do
    sign_in_as(@user)
    get feed_entries_path(@feed), headers: { "Turbo-Frame": "entry_list" }
    assert_response :success
  end

  test "show requires authentication" do
    get entry_path(@entry)
    assert_redirected_to new_session_path
  end

  test "show displays entry detail" do
    sign_in_as(@user)
    get entry_path(@entry)
    assert_response :success
    assert_select "turbo-frame#entry_detail"
    assert_select ".entry-detail"
  end

  test "show marks entry as read" do
    sign_in_as(@user)
    assert_nil @entry.read_at

    get entry_path(@entry)
    assert_not_nil @entry.reload.read_at
  end

  test "show renders mobile navigation buttons" do
    sign_in_as(@user)
    get entry_path(@entry)
    assert_response :success

    assert_select "nav.mobile-entry-nav" do
      assert_select "button[data-selection-target='prevButton'][aria-label='前のエントリに移動']", text: /前のエントリ/
      assert_select "button[data-selection-target='nextButton'][aria-label='次のエントリに移動']", text: /次のエントリ/
    end
  end

  test "show is turbo frame compatible" do
    sign_in_as(@user)
    get entry_path(@entry), headers: { "Turbo-Frame": "entry_detail" }
    assert_response :success
  end

  test "pinned requires authentication" do
    get pinned_entries_path
    assert_redirected_to new_session_path
  end

  test "pinned shows pinned entries" do
    sign_in_as(@user)
    # まずエントリをピン留め
    entry = entries(:ruby_article_one)
    entry.update!(pinned: true)

    get pinned_entries_path
    assert_response :success
    assert_select ".entry-item", minimum: 1
  end

  test "pinned shows empty message when no pinned entries" do
    sign_in_as(@user)
    Entry.update_all(pinned: false)

    get pinned_entries_path
    assert_response :success
    assert_select ".empty-message"
  end
end
