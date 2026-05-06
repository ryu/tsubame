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

  test "create adds feed with valid feed URL" do
    sign_in_as(@user)

    # Stub direct feed URL (Content-Type: application/rss+xml)
    stub_request(:get, "https://example.com/new/feed.xml")
      .to_return(
        status: 200,
        body: '<?xml version="1.0"?><rss version="2.0"><channel><title>New Feed</title></channel></rss>',
        headers: { "Content-Type" => "application/rss+xml" }
      )

    assert_difference "Feed.count", 1 do
      assert_difference "Subscription.count", 1 do
        post feeds_path, params: { feed: { url: "https://example.com/new/feed.xml" } }
      end
    end

    assert_redirected_to feeds_path
    assert_equal "フィードを追加しました。", flash[:notice]

    feed = Feed.last
    assert_equal "https://example.com/new/feed.xml", feed.url
    assert_not_nil feed.next_fetch_at
  end

  test "create autodiscovers single feed from HTML and registers it" do
    sign_in_as(@user)

    html_content = <<~HTML
      <!DOCTYPE html>
      <html>
        <head>
          <title>My Blog</title>
          <link rel="alternate" type="application/rss+xml" href="/blog/feed.xml">
        </head>
        <body>Content</body>
      </html>
    HTML

    stub_request(:get, "https://example.com/blog")
      .to_return(
        status: 200,
        body: html_content,
        headers: { "Content-Type" => "text/html; charset=utf-8" }
      )

    assert_difference "Feed.count", 1 do
      post feeds_path, params: { feed: { url: "https://example.com/blog" } }
    end

    assert_redirected_to feeds_path
    assert_equal "フィードを追加しました。", flash[:notice]

    feed = Feed.last
    assert_equal "https://example.com/blog/feed.xml", feed.url
  end

  test "create shows select_feed view when multiple feeds detected" do
    sign_in_as(@user)

    html_content = <<~HTML
      <!DOCTYPE html>
      <html>
        <head>
          <title>Multi Feed Blog</title>
          <link rel="alternate" type="application/rss+xml" href="https://example.com/rss">
          <link rel="alternate" type="application/atom+xml" href="https://example.com/atom">
        </head>
      </html>
    HTML

    stub_request(:get, "https://example.com/multi")
      .to_return(
        status: 200,
        body: html_content,
        headers: { "Content-Type" => "text/html; charset=utf-8" }
      )

    post feeds_path, params: { feed: { url: "https://example.com/multi" } }

    assert_redirected_to select_feeds_path
    follow_redirect!
    assert_select "input[type=radio][value='https://example.com/rss']"
    assert_select "input[type=radio][value='https://example.com/atom']"
  end

  test "create falls back to registering raw HTML URL when no feed links found" do
    sign_in_as(@user)

    html_content = <<~HTML
      <!DOCTYPE html>
      <html>
        <head>
          <title>No Feed Blog</title>
        </head>
        <body>Content</body>
      </html>
    HTML

    stub_request(:get, "https://example.com/nofeed")
      .to_return(
        status: 200,
        body: html_content,
        headers: { "Content-Type" => "text/html; charset=utf-8" }
      )
    Feed::Autodiscovery::GUESS_PATHS.each do |path|
      stub_request(:head, "https://example.com#{path}").to_return(status: 404)
    end

    assert_difference "Feed.count", 1 do
      post feeds_path, params: { feed: { url: "https://example.com/nofeed" } }
    end

    assert_redirected_to feeds_path
    feed = Feed.last
    assert_equal "https://example.com/nofeed", feed.url
  end

  test "create falls back to registration when autodiscovery raises StandardError" do
    sign_in_as(@user)

    # Simulate a network error during autodiscovery
    stub_request(:get, "https://example.com/unreliable")
      .to_timeout

    # The controller catches the error and tries to register the URL as-is
    # The URL is still valid HTTP, so it will be registered
    assert_difference "Feed.count", 1 do
      post feeds_path, params: { feed: { url: "https://example.com/unreliable" } }
    end

    assert_redirected_to feeds_path
    feed = Feed.last
    assert_equal "https://example.com/unreliable", feed.url
  end

  test "create rejects SSRF URL during autodiscovery with error message" do
    sign_in_as(@user)

    assert_no_difference "Feed.count" do
      post feeds_path, params: { feed: { url: "http://169.254.169.254/feed.xml" } }
    end

    assert_response :unprocessable_entity
    assert_select "input[name='feed[url]']"
  end

  test "create rejects SSRF URL when submitted from select_feed form" do
    sign_in_as(@user)

    # SSRF attempt directly on the URL field
    assert_no_difference "Feed.count" do
      post feeds_path, params: { feed: { url: "http://192.168.1.1/feed.xml" } }
    end

    assert_response :unprocessable_entity
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

    # Stub the autodiscovery request for the existing feed URL
    stub_request(:get, feeds(:ruby_blog).url)
      .to_return(
        status: 200,
        body: '<?xml version="1.0"?><rss version="2.0"><channel><title>Test</title></channel></rss>',
        headers: { "Content-Type" => "application/rss+xml" }
      )

    assert_no_difference "Feed.count" do
      post feeds_path, params: { feed: { url: feeds(:ruby_blog).url } }
    end

    # User already has a subscription, so it should redirect (find_or_create_by)
    assert_redirected_to feeds_path
  end

  test "create shows already subscribed notice when posting an already subscribed feed URL" do
    sign_in_as(@user)

    stub_request(:get, feeds(:ruby_blog).url)
      .to_return(
        status: 200,
        body: '<?xml version="1.0"?><rss version="2.0"><channel><title>Ruby Blog</title></channel></rss>',
        headers: { "Content-Type" => "application/rss+xml" }
      )

    assert_no_difference "Subscription.count" do
      post feeds_path, params: { feed: { url: feeds(:ruby_blog).url } }
    end

    assert_redirected_to feeds_path
    assert_equal "既に登録済みのフィードです。", flash[:notice]
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
  end

  test "update changes title" do
    sign_in_as(@user)
    feed = feeds(:ruby_blog)
    subscription = @user.subscriptions.find_by!(feed: feed)

    patch feed_path(feed), params: { subscription: { title: "New Title" } }

    assert_redirected_to feeds_path
    assert_equal "フィードを更新しました。", flash[:notice]
    assert_equal "New Title", subscription.reload.title
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

    assert_difference "Subscription.count", -1 do
      assert_difference "Feed.count", -1 do
        assert_difference "Entry.count", -entry_count do
          delete feed_path(feed)
        end
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

  # -- Rate tests --

  test "edit form shows rate select field" do
    sign_in_as(@user)
    feed = feeds(:ruby_blog)
    get edit_feed_path(feed)

    assert_response :success
    assert_select "select[name='subscription[rate]']" do
      # Verify rate options: 0-5
      (0..5).each do |rate|
        assert_select "option[value='#{rate}']"
      end
    end
  end

  test "update changes rate" do
    sign_in_as(@user)
    feed = feeds(:ruby_blog)
    subscription = @user.subscriptions.find_by!(feed: feed)

    patch feed_path(feed), params: { subscription: { rate: 3 } }

    assert_redirected_to feeds_path
    assert_equal "フィードを更新しました。", flash[:notice]
    assert_equal 3, subscription.reload.rate
  end

  test "update changes rate from 3 to 5" do
    sign_in_as(@user)
    feed = feeds(:rails_news)
    subscription = @user.subscriptions.find_by!(feed: feed)
    assert_equal 3, subscription.rate

    patch feed_path(feed), params: { subscription: { rate: 5 } }

    assert_equal 5, subscription.reload.rate
  end

  test "update changes rate to 0" do
    sign_in_as(@user)
    feed = feeds(:ruby_blog)
    subscription = @user.subscriptions.find_by!(feed: feed)

    patch feed_path(feed), params: { subscription: { rate: 0 } }

    assert_equal 0, subscription.reload.rate
  end

  test "update rejects invalid rate (negative)" do
    sign_in_as(@user)
    feed = feeds(:ruby_blog)
    subscription = @user.subscriptions.find_by!(feed: feed)
    original_rate = subscription.rate

    patch feed_path(feed), params: { subscription: { rate: -1 } }

    assert_response :unprocessable_entity
    assert_equal original_rate, subscription.reload.rate
  end

  test "update rejects invalid rate (> 5)" do
    sign_in_as(@user)
    feed = feeds(:ruby_blog)
    subscription = @user.subscriptions.find_by!(feed: feed)
    original_rate = subscription.rate

    patch feed_path(feed), params: { subscription: { rate: 6 } }

    assert_response :unprocessable_entity
    assert_equal original_rate, subscription.reload.rate
  end

  test "update accepts rate with title change" do
    sign_in_as(@user)
    feed = feeds(:ruby_blog)
    subscription = @user.subscriptions.find_by!(feed: feed)

    patch feed_path(feed), params: { subscription: { title: "Updated Title", rate: 4 } }

    assert_redirected_to feeds_path
    subscription.reload
    assert_equal "Updated Title", subscription.title
    assert_equal 4, subscription.rate
  end

  # -- Folder-related tests --

  test "new shows folder select when authenticated" do
    sign_in_as(@user)
    get new_feed_path

    assert_response :success
    assert_select "select"  # Folder select should be present
  end

  test "edit shows folder select when authenticated" do
    sign_in_as(@user)
    feed = feeds(:ruby_blog)

    get edit_feed_path(feed)

    assert_response :success
    assert_select "select"  # Folder select should be present
  end

  test "update assigns feed to folder" do
    sign_in_as(@user)
    feed = feeds(:error_feed)  # Use a feed without folder initially
    subscription = @user.subscriptions.find_by!(feed: feed)
    folder = folders(:news)

    patch feed_path(feed), params: { subscription: { folder_id: folder.id } }

    assert_redirected_to feeds_path
    assert_equal folder.id, subscription.reload.folder_id
  end

  test "update removes feed from folder" do
    sign_in_as(@user)
    feed = feeds(:ruby_blog)  # ruby_blog subscription is in tech folder
    subscription = @user.subscriptions.find_by!(feed: feed)

    assert_not_nil subscription.folder_id

    patch feed_path(feed), params: { subscription: { folder_id: "" } }

    assert_redirected_to feeds_path
    assert_nil subscription.reload.folder_id
  end

  test "update changes feed folder" do
    sign_in_as(@user)
    feed = feeds(:ruby_blog)  # Currently in tech folder
    subscription = @user.subscriptions.find_by!(feed: feed)
    new_folder = folders(:news)

    patch feed_path(feed), params: { subscription: { folder_id: new_folder.id } }

    assert_redirected_to feeds_path
    assert_equal new_folder.id, subscription.reload.folder_id
  end

  test "update keeps folder when only title changes" do
    sign_in_as(@user)
    feed = feeds(:ruby_blog)
    subscription = @user.subscriptions.find_by!(feed: feed)
    original_folder_id = subscription.folder_id

    patch feed_path(feed), params: { subscription: { title: "New Title" } }

    assert_redirected_to feeds_path
    subscription.reload
    assert_equal "New Title", subscription.title
    assert_equal original_folder_id, subscription.folder_id
  end

  # -- Cross-user data isolation tests --

  test "edit returns not found for unsubscribed feed" do
    sign_in_as(users(:two))
    get edit_feed_path(feeds(:ruby_blog))
    assert_response :not_found
  end

  test "update returns not found for unsubscribed feed" do
    sign_in_as(users(:two))
    patch feed_path(feeds(:ruby_blog)), params: { subscription: { title: "Hacked" } }
    assert_response :not_found
  end

  test "destroy returns not found for unsubscribed feed" do
    sign_in_as(users(:two))
    delete feed_path(feeds(:ruby_blog))
    assert_response :not_found
  end
end
