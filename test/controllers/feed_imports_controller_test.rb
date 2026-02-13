require "test_helper"

class FeedImportsControllerTest < ActionDispatch::IntegrationTest
  setup do
    @user = users(:one)
  end

  test "new requires authentication" do
    get new_feed_import_path
    assert_redirected_to new_session_path
  end

  test "new shows form when authenticated" do
    sign_in_as(@user)
    get new_feed_import_path
    assert_response :success
    assert_select "h1", "OPMLインポート"
    assert_select "input[type=file]"
  end

  test "create requires authentication" do
    post feed_imports_path
    assert_redirected_to new_session_path
  end

  test "create imports valid OPML file" do
    sign_in_as(@user)
    opml_file = fixture_file_upload("sample.opml", "application/xml")

    assert_difference "Feed.count", 3 do
      post feed_imports_path, params: { opml_file: opml_file }
    end

    assert_redirected_to feeds_path
    assert_equal "3件のフィードを追加しました。（0件スキップ）", flash[:notice]
  end

  test "create skips duplicate feeds" do
    sign_in_as(@user)
    opml_file = fixture_file_upload("sample.opml", "application/xml")

    # First import
    post feed_imports_path, params: { opml_file: opml_file }

    # Second import should skip all
    assert_no_difference "Feed.count" do
      post feed_imports_path, params: { opml_file: opml_file }
    end

    assert_redirected_to feeds_path
    assert_equal "0件のフィードを追加しました。（3件スキップ）", flash[:notice]
  end

  test "create redirects with error when no file selected" do
    sign_in_as(@user)

    post feed_imports_path, params: { opml_file: nil }

    assert_redirected_to new_feed_import_path
    assert_equal "ファイルを選択してください。", flash[:alert]
  end

  test "create rejects non-XML file content" do
    sign_in_as(@user)
    non_xml = Rack::Test::UploadedFile.new(
      StringIO.new("This is not XML at all"),
      "application/xml",
      original_filename: "fake.opml"
    )

    assert_no_difference "Feed.count" do
      post feed_imports_path, params: { opml_file: non_xml }
    end

    assert_redirected_to new_feed_import_path
    assert_equal "XMLファイルを選択してください。", flash[:alert]
  end

  test "create rejects files larger than 5MB" do
    sign_in_as(@user)
    file = Tempfile.new([ "large", ".opml" ])
    file.write("x" * (5.megabytes + 1))
    file.rewind

    assert_no_difference "Feed.count" do
      post feed_imports_path, params: {
        opml_file: Rack::Test::UploadedFile.new(file.path, "application/xml")
      }
    end

    assert_redirected_to new_feed_import_path
    assert_equal "ファイルサイズは5MB以下にしてください。", flash[:alert]
  ensure
    file&.close
    file&.unlink
  end

  test "create handles invalid OPML file" do
    sign_in_as(@user)
    invalid_file = fixture_file_upload("invalid.opml", "application/xml")

    post feed_imports_path, params: { opml_file: invalid_file }

    assert_redirected_to new_feed_import_path
    assert_match(/インポートに失敗しました/, flash[:alert])
  end
end
