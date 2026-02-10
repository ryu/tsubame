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
end
