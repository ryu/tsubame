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

  test "import requires authentication" do
    get import_feeds_path
    assert_redirected_to new_session_path
  end

  test "import shows form when authenticated" do
    sign_in_as(@user)
    get import_feeds_path
    assert_response :success
    assert_select "h1", "OPMLインポート"
    assert_select "input[type=file]"
  end

  test "create_import requires authentication" do
    post import_feeds_path
    assert_redirected_to new_session_path
  end

  test "create_import imports valid OPML file" do
    sign_in_as(@user)
    opml_file = fixture_file_upload("sample.opml", "application/xml")

    assert_difference "Feed.count", 3 do
      post import_feeds_path, params: { opml_file: opml_file }
    end

    assert_redirected_to feeds_path
    assert_equal "3件のフィードを追加しました。（0件スキップ）", flash[:notice]
  end

  test "create_import skips duplicate feeds" do
    sign_in_as(@user)
    opml_file = fixture_file_upload("sample.opml", "application/xml")

    # First import
    post import_feeds_path, params: { opml_file: opml_file }

    # Second import should skip all
    assert_no_difference "Feed.count" do
      post import_feeds_path, params: { opml_file: opml_file }
    end

    assert_redirected_to feeds_path
    assert_equal "0件のフィードを追加しました。（3件スキップ）", flash[:notice]
  end

  test "create_import redirects with error when no file selected" do
    sign_in_as(@user)

    post import_feeds_path, params: { opml_file: nil }

    assert_redirected_to import_feeds_path
    assert_equal "ファイルを選択してください。", flash[:alert]
  end

  test "create_import handles invalid OPML file" do
    sign_in_as(@user)
    invalid_file = fixture_file_upload("invalid.opml", "application/xml")

    post import_feeds_path, params: { opml_file: invalid_file }

    assert_redirected_to import_feeds_path
    assert_match(/インポートに失敗しました/, flash[:alert])
  end

  test "mark_all_as_read requires authentication" do
    post mark_all_as_read_feed_path(feeds(:ruby_blog))
    assert_redirected_to new_session_path
  end

  test "mark_all_as_read marks all entries as read" do
    sign_in_as(@user)
    feed = feeds(:ruby_blog)
    assert feed.entries.unread.exists?

    post mark_all_as_read_feed_path(feed)
    assert_response :success

    json = JSON.parse(response.body)
    assert json["success"]
    assert json["marked_count"] > 0
    assert_not feed.entries.reload.unread.exists?
  end

  test "export requires authentication" do
    get export_feeds_path
    assert_redirected_to new_session_path
  end

  test "export returns OPML file" do
    sign_in_as(@user)

    get export_feeds_path
    assert_response :success
    assert_equal "application/xml", response.media_type
    assert_match /attachment/, response.headers["Content-Disposition"]
    assert_match /subscriptions\.opml/, response.headers["Content-Disposition"]
    assert_match /<opml version=['"]1\.0['"]>/, response.body
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

  # --- fetch_now tests ---

  test "fetch_now requires authentication" do
    post fetch_now_feed_path(feeds(:ruby_blog))
    assert_redirected_to new_session_path
  end

  test "fetch_now performs fetch and redirects" do
    sign_in_as(@user)
    feed = feeds(:ruby_blog)

    rss_body = <<~XML
      <?xml version="1.0" encoding="UTF-8"?>
      <rss version="2.0">
        <channel>
          <title>Ruby Blog</title>
          <link>https://example.com/ruby</link>
          <item>
            <title>Test Entry</title>
            <link>https://example.com/ruby/test</link>
            <guid>test-entry-fetch-now</guid>
          </item>
        </channel>
      </rss>
    XML

    stub_request(:get, feed.url)
      .to_return(status: 200, body: rss_body, headers: { "Content-Type" => "application/rss+xml" })

    post fetch_now_feed_path(feed)

    assert_redirected_to feeds_path
    assert_match(/フェッチしました/, flash[:notice])
    assert feed.reload.ok?
  end

  test "fetch_now handles fetch failure gracefully" do
    sign_in_as(@user)
    feed = feeds(:ruby_blog)

    stub_request(:get, feed.url).to_return(status: 500, body: "Internal Server Error")

    post fetch_now_feed_path(feed)

    assert_redirected_to feeds_path
    # FetchFeedJob marks the feed as error, but the controller catches exceptions
    # and shows a success message since no exception is raised to the controller
    assert feed.reload.error?
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
