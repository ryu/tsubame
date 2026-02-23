require "test_helper"

class HomeControllerTest < ActionDispatch::IntegrationTest
  test "unauthenticated user is redirected to login" do
    get root_url
    assert_redirected_to new_session_url
  end

  test "authenticated user sees home page" do
    user = User.create!(email_address: "user@example.com", password: "password")
    post session_url, params: { email_address: user.email_address, password: "password" }

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

  # -- Rate filtering tests --

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

    # Should include rails_news (rate: 3) and ruby_blog (rate: 5)
    assert_select "a[href='#{feed_entries_path(feeds(:rails_news))}']"
    assert_select "a[href='#{feed_entries_path(feeds(:ruby_blog))}']"
  end

  test "home page filters feeds by rate >= 5" do
    sign_in_as(users(:one))

    get root_url(rate: 5)
    assert_response :success

    # Should only include ruby_blog (rate: 5)
    assert_select "a[href='#{feed_entries_path(feeds(:ruby_blog))}']"
  end

  test "home page displays all feeds when rate=0" do
    sign_in_as(users(:one))

    get root_url(rate: 0)
    assert_response :success

    # Should include all feeds
    assert_select ".feed-item", minimum: 2
  end

  test "home page safely handles invalid rate parameter (non-numeric)" do
    sign_in_as(users(:one))

    get root_url(rate: "invalid")
    assert_response :success

    # Should display all feeds (fallback)
    assert_select ".feed-item", minimum: 2
  end

  test "home page safely handles invalid rate parameter (negative)" do
    sign_in_as(users(:one))

    get root_url(rate: -1)
    assert_response :success

    # Should display all feeds (fallback)
    assert_select ".feed-item", minimum: 2
  end

  test "home page displays correct feed count for rate filter" do
    sign_in_as(users(:one))

    # HomeController uses with_unreads, so only feeds with unread entries are shown
    # Current fixtures:
    #   ruby_blog (rate=5): has unread entry
    #   rails_news (rate=3): has unread entry
    #   error_feed (rate=0): no unread entries
    #   low_rate_feed (rate=1): no unread entries

    # rate=1: only feeds with rate >= 1 AND unread entries = rails_news, ruby_blog (2 feeds)
    get root_url(rate: 1)
    assert_select ".feed-item", { count: 2 }

    # rate=3: only feeds with rate >= 3 AND unread entries = rails_news, ruby_blog (2 feeds)
    get root_url(rate: 3)
    assert_select ".feed-item", { count: 2 }

    # rate=5: only feeds with rate >= 5 AND unread entries = ruby_blog (1 feed)
    get root_url(rate: 5)
    assert_select ".feed-item", { count: 1 }
  end
end
