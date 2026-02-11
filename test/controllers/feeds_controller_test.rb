require "test_helper"

class FeedsControllerTest < ActionDispatch::IntegrationTest
  setup do
    @user = users(:one)
  end

  test "index requires authentication" do
    get feeds_path
    assert_redirected_to new_session_path
  end

  test "index shows feeds when authenticated" do
    sign_in_as(@user)
    get feeds_path
    assert_response :success
    assert_select "h1", "フィード管理"
  end

  # --- new/create tests ---

  test "new requires authentication" do
    get new_feed_path
    assert_redirected_to new_session_path
  end

  test "new shows form when authenticated" do
    sign_in_as(@user)
    get new_feed_path
    assert_response :success
    assert_select "h1", "フィードを追加"
    assert_select "input[type=url]"
  end

  test "create adds feed with valid URL" do
    sign_in_as(@user)

    assert_difference "Feed.count", 1 do
      post feeds_path, params: { feed: { url: "https://example.com/new/feed.xml" } }
    end

    assert_redirected_to feeds_path
    assert_equal "フィードを追加しました。", flash[:notice]

    feed = Feed.last
    assert_equal "https://example.com/new/feed.xml", feed.url
    assert_not_nil feed.next_fetch_at
  end

  test "create rejects invalid URL" do
    sign_in_as(@user)

    assert_no_difference "Feed.count" do
      post feeds_path, params: { feed: { url: "not-a-url" } }
    end

    assert_response :unprocessable_entity
  end

  test "create rejects duplicate URL" do
    sign_in_as(@user)

    assert_no_difference "Feed.count" do
      post feeds_path, params: { feed: { url: feeds(:ruby_blog).url } }
    end

    assert_response :unprocessable_entity
  end

  test "create rejects blank URL" do
    sign_in_as(@user)

    assert_no_difference "Feed.count" do
      post feeds_path, params: { feed: { url: "" } }
    end

    assert_response :unprocessable_entity
  end

  # --- edit/update tests ---

  test "edit requires authentication" do
    get edit_feed_path(feeds(:ruby_blog))
    assert_redirected_to new_session_path
  end

  test "edit shows form when authenticated" do
    sign_in_as(@user)
    feed = feeds(:ruby_blog)
    get edit_feed_path(feed)
    assert_response :success
    assert_select "h1", "フィードを編集"
    assert_select "input[value=?]", feed.title
  end

  test "update changes title" do
    sign_in_as(@user)
    feed = feeds(:ruby_blog)

    patch feed_path(feed), params: { feed: { title: "New Title" } }

    assert_redirected_to feeds_path
    assert_equal "フィードを更新しました。", flash[:notice]
    assert_equal "New Title", feed.reload.title
  end

  test "update changes fetch_interval_minutes" do
    sign_in_as(@user)
    feed = feeds(:ruby_blog)
    patch feed_path(feed), params: { feed: { fetch_interval_minutes: 360 } }
    assert_redirected_to feeds_path
    assert_equal 360, feed.reload.fetch_interval_minutes
  end

  test "update rejects invalid fetch_interval_minutes" do
    sign_in_as(@user)
    feed = feeds(:ruby_blog)
    patch feed_path(feed), params: { feed: { fetch_interval_minutes: 999 } }
    assert_response :unprocessable_entity
    assert_not_equal 999, feed.reload.fetch_interval_minutes
  end

  test "edit shows fetch_interval_minutes select field" do
    sign_in_as(@user)
    feed = feeds(:ruby_blog)
    get edit_feed_path(feed)
    assert_response :success
    assert_select "select[name='feed[fetch_interval_minutes]']"
    Feed::FETCH_INTERVAL_OPTIONS.each do |minutes, label|
      assert_select "option[value='#{minutes}']", text: label
    end
  end

  # --- destroy tests ---

  test "destroy requires authentication" do
    delete feed_path(feeds(:ruby_blog))
    assert_redirected_to new_session_path
  end

  test "destroy removes feed and entries" do
    sign_in_as(@user)
    feed = feeds(:ruby_blog)
    entry_count = feed.entries.count

    assert_difference "Feed.count", -1 do
      assert_difference "Entry.count", -entry_count do
        delete feed_path(feed)
      end
    end

    assert_redirected_to feeds_path
    assert_equal "フィードを削除しました。", flash[:notice]
  end

  test "index shows status badges and action buttons" do
    sign_in_as(@user)
    get feeds_path

    assert_select ".status-ok"
    assert_select ".status-error"
    assert_select "a", text: "編集"
    assert_select "button", text: "↻"
    assert_select "a", text: "削除"
  end
end
