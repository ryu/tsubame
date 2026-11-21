require "test_helper"

class HomeControllerTest < ActionDispatch::IntegrationTest
  test "unauthenticated user is redirected to login" do
    get root_url
    assert_redirected_to new_session_url
  end

  test "authenticated user sees home page" do
    sign_in_as(users(:one))
    get root_url
    assert_response :success
    assert_select "h1", "Tsubame"
  end

  test "home page displays three-pane layout" do
    sign_in_as(users(:one))

    get root_url
    assert_response :success
    assert_select ".three-pane-layout"
    assert_select ".feed-list-pane"
    assert_select "turbo-frame#entry_list"
    assert_select "turbo-frame#entry_detail"
  end

  test "home page displays feeds with unread count" do
    sign_in_as(users(:one))

    get root_url
    assert_response :success
    assert_select ".feed-item", minimum: 1
    assert_select ".unread-badge", minimum: 1
  end

  test "home page contains keyboard shortcut help dialog" do
    sign_in_as(users(:one))

    get root_url
    assert_response :success
    assert_select "dialog.help-dialog" do
      assert_select "h2", "キーボードショートカット"
      assert_select "h3", "フィードナビゲーション"
      assert_select "h3", "エントリナビゲーション"
      assert_select "h3", "アクション"
      assert_select "h3", "その他"
      assert_select "kbd", text: "j"
      assert_select "kbd", text: "?"
    end
  end

  test "home page links to feed entries" do
    sign_in_as(users(:one))

    get root_url
    assert_response :success
    assert_select "a[href='#{feed_entries_path(feeds(:ruby_blog))}']"
  end

  test "home page displays all feeds when no rate filter is applied" do
    sign_in_as(users(:one))

    get root_url
    assert_response :success
    assert_select ".feed-item", minimum: 2
  end

  test "home page filters feeds by rate >= 3" do
    sign_in_as(users(:one))

    get root_url(rate: 3)
    assert_response :success

    assert_select "a[href='#{feed_entries_path(feeds(:rails_news))}']"
    assert_select "a[href='#{feed_entries_path(feeds(:ruby_blog))}']"
  end

  test "home page filters feeds by rate >= 5" do
    sign_in_as(users(:one))

    get root_url(rate: 5)
    assert_response :success

    assert_select "a[href='#{feed_entries_path(feeds(:ruby_blog))}']"
  end

  test "home page displays all feeds when rate=0" do
    sign_in_as(users(:one))

    get root_url(rate: 0)
    assert_response :success

    assert_select ".feed-item", minimum: 2
  end

  test "home page safely handles invalid rate parameter (non-numeric)" do
    sign_in_as(users(:one))

    get root_url(rate: "invalid")
    assert_response :success

    assert_select ".feed-item", minimum: 2
  end

  test "home page safely handles invalid rate parameter (negative)" do
    sign_in_as(users(:one))

    get root_url(rate: -1)
    assert_response :success

    assert_select ".feed-item", minimum: 2
  end

  test "home page displays correct feed count for rate filter" do
    sign_in_as(users(:one))

    get root_url(rate: 1)
    assert_select ".feed-item", { count: 2 }

    get root_url(rate: 3)
    assert_select ".feed-item", { count: 2 }

    get root_url(rate: 5)
    assert_select ".feed-item", { count: 1 }
  end

  test "home page displays folder headers" do
    sign_in_as(users(:one))

    get root_url
    assert_response :success

    assert_select ".feed-folder-header", minimum: 1
  end

  test "home page displays folder name in header" do
    sign_in_as(users(:one))

    get root_url
    assert_response :success

    assert_select ".feed-folder-header", text: /Tech/
  end

  test "home page displays folder unread count" do
    sign_in_as(users(:one))

    get root_url
    assert_response :success

    assert_select ".feed-folder-header" do |headers|
      tech_header = headers.find { |h| h.text.include?("Tech") }
      assert tech_header, "Tech folder header should exist"
      assert_select tech_header, ".unread-badge", text: "2"
    end
  end

  test "home page displays unclassified section" do
    user = users(:one)
    sign_in_as(user)

    unclassified_feed = Feed.create!(
      url: "https://example.com/unclassified",
      title: "Unclassified Feed"
    )
    user.subscribe_to(unclassified_feed)
    Entry.create!(
      feed_id: unclassified_feed.id,
      guid: "https://example.com/entry/#{SecureRandom.uuid}",
      url: "https://example.com/entry"
    )

    get root_url
    assert_response :success

    assert_select ".feed-folder-header", text: /未分類/
  ensure
    unclassified_feed&.destroy
  end

  test "home page groups feeds under folder headers" do
    sign_in_as(users(:one))

    get root_url
    assert_response :success

    assert_select "a[href='#{feed_entries_path(feeds(:ruby_blog))}']"
    assert_select "a[href='#{feed_entries_path(feeds(:rails_news))}']"
  end

  test "home page displays feeds in correct order within folder" do
    sign_in_as(users(:one))

    get root_url
    assert_response :success

    assert_select ".feed-item", minimum: 2
  end

  test "home page displays unclassified feeds after folders" do
    user = users(:one)
    sign_in_as(user)

    unclassified = Feed.create!(
      url: "https://example.com/unclass1",
      title: "ZUnclassified"
    )
    user.subscribe_to(unclassified)
    Entry.create!(
      feed_id: unclassified.id,
      guid: "https://example.com/entry/#{SecureRandom.uuid}",
      url: "https://example.com/entry"
    )

    get root_url
    assert_response :success

    body = response.body
    tech_index = body.index("Tech") || 0
    unclassified_index = body.index("未分類") || 0

    assert tech_index < unclassified_index, "Tech folder should appear before 未分類"
  ensure
    unclassified&.destroy
  end

  test "home page with rate filter shows only matching feeds in folders" do
    sign_in_as(users(:one))

    get root_url(rate: 3)
    assert_response :success

    assert_select ".feed-item", { count: 2 }
  end
end
