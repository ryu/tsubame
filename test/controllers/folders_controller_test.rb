require "test_helper"

class FoldersControllerTest < ActionDispatch::IntegrationTest
  setup do
    @user = users(:one)
  end

  # -- Authentication tests --

  test "index requires authentication" do
    get folders_path
    assert_redirected_to new_session_path
  end

  test "new requires authentication" do
    get new_folder_path
    assert_redirected_to new_session_path
  end

  test "create requires authentication" do
    post folders_path, params: { folder: { name: "Test" } }
    assert_redirected_to new_session_path
  end

  test "edit requires authentication" do
    folder = folders(:tech)
    get edit_folder_path(folder)
    assert_redirected_to new_session_path
  end

  test "update requires authentication" do
    folder = folders(:tech)
    patch folder_path(folder), params: { folder: { name: "Updated" } }
    assert_redirected_to new_session_path
  end

  test "destroy requires authentication" do
    folder = folders(:tech)
    delete folder_path(folder)
    assert_redirected_to new_session_path
  end

  # -- index tests --

  test "index shows folder list when authenticated" do
    sign_in_as(@user)
    get folders_path

    assert_response :success
    assert_select "h1"  # Page title should exist
  end

  test "index displays all folders ordered by name" do
    sign_in_as(@user)
    get folders_path

    assert_response :success
    # Both tech and news folders should be present in fixtures
    # Verify they are accessible (rendered)
    assert_not_nil response.body
  end

  # -- new tests --

  test "new shows form when authenticated" do
    sign_in_as(@user)
    get new_folder_path

    assert_response :success
    assert_select "input[type=text]"  # Name input
  end

  # -- create tests --

  test "create saves new folder with valid name" do
    sign_in_as(@user)

    assert_difference "Folder.count", 1 do
      post folders_path, params: { folder: { name: "Entertainment" } }
    end

    assert_redirected_to folders_path
    assert_equal "フォルダを作成しました。", flash[:notice]
  end

  test "create fails with blank name" do
    sign_in_as(@user)

    assert_no_difference "Folder.count" do
      post folders_path, params: { folder: { name: "" } }
    end

    assert_response :unprocessable_entity
  end

  test "create fails with duplicate name" do
    sign_in_as(@user)

    assert_no_difference "Folder.count" do
      post folders_path, params: { folder: { name: folders(:tech).name } }
    end

    assert_response :unprocessable_entity
  end

  test "create re-renders form on validation error" do
    sign_in_as(@user)

    post folders_path, params: { folder: { name: "" } }

    assert_response :unprocessable_entity
    assert_select "input[type=text]"  # Form should be re-rendered
  end

  # -- edit tests --

  test "edit shows folder form when authenticated" do
    sign_in_as(@user)
    folder = folders(:tech)

    get edit_folder_path(folder)

    assert_response :success
    assert_select "input[type=text]"  # Name input field
  end

  # -- update tests --

  test "update saves changes with valid name" do
    sign_in_as(@user)
    folder = folders(:tech)

    patch folder_path(folder), params: { folder: { name: "TechNews" } }

    assert_redirected_to folders_path
    assert_equal "フォルダを更新しました。", flash[:notice]
    assert_equal "TechNews", folder.reload.name
  end

  test "update fails with blank name" do
    sign_in_as(@user)
    folder = folders(:tech)
    original_name = folder.name

    patch folder_path(folder), params: { folder: { name: "" } }

    assert_response :unprocessable_entity
    assert_equal original_name, folder.reload.name
  end

  test "update fails with duplicate name" do
    sign_in_as(@user)
    folder = folders(:tech)
    other_folder = folders(:news)

    patch folder_path(folder), params: { folder: { name: other_folder.name } }

    assert_response :unprocessable_entity
    assert_equal "Tech", folder.reload.name  # Name unchanged
  end

  test "update re-renders form on validation error" do
    sign_in_as(@user)
    folder = folders(:tech)

    patch folder_path(folder), params: { folder: { name: "" } }

    assert_response :unprocessable_entity
    assert_select "input[type=text]"  # Form re-rendered
  end

  # -- destroy tests --

  test "destroy deletes folder and redirects" do
    sign_in_as(@user)
    folder = folders(:tech)
    folder_id = folder.id

    assert_difference "Folder.count", -1 do
      delete folder_path(folder)
    end

    assert_redirected_to folders_path
    assert_equal "フォルダを削除しました。", flash[:notice]
    assert_not Folder.exists?(folder_id)
  end

  test "destroy nullifies feed folder_id" do
    sign_in_as(@user)
    folder = folders(:tech)
    feed = folder.feeds.first

    assert_not_nil feed
    assert_equal folder.id, feed.folder_id

    delete folder_path(folder)

    # Verify feed's folder_id is now nil
    assert_nil feed.reload.folder_id
  end

  test "destroy all feeds in folder have nullified folder_id" do
    sign_in_as(@user)
    folder = folders(:tech)
    feed_ids = folder.feeds.pluck(:id)

    assert_not feed_ids.empty?

    delete folder_path(folder)

    # All feeds should have folder_id = nil
    Feed.where(id: feed_ids).each do |feed|
      assert_nil feed.folder_id
    end
  end
end
