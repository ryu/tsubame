require "test_helper"

class PinnedEntryOpensControllerTest < ActionDispatch::IntegrationTest
  setup do
    @user = users(:one)
  end

  test "create requires authentication" do
    post pinned_entry_open_path
    assert_redirected_to new_session_path
  end

  test "create returns URLs without unpinning entries" do
    sign_in_as(@user)
    entry1 = entries(:ruby_article_one)
    entry2 = entries(:ruby_article_two)
    entry1.update!(pinned: true, url: "https://example.com/1")
    entry2.update!(pinned: true, url: "https://example.com/2")

    post pinned_entry_open_path
    assert_response :success

    json = JSON.parse(response.body)
    assert_equal 2, json["urls"].length
    assert_includes json["urls"], "https://example.com/1"
    assert_includes json["urls"], "https://example.com/2"
    assert_equal 2, json["entry_ids"].length
    assert entry1.reload.pinned, "entry should still be pinned"
    assert entry2.reload.pinned, "entry should still be pinned"
  end

  test "create handles no pinned entries" do
    sign_in_as(@user)
    Entry.update_all(pinned: false)

    post pinned_entry_open_path
    assert_response :success

    json = JSON.parse(response.body)
    assert_equal 0, json["urls"].length
  end

  test "create limits to 5 entries" do
    sign_in_as(@user)
    feed = feeds(:ruby_blog)
    6.times do |i|
      feed.entries.create!(
        guid: "pin-test-#{i}",
        title: "Pinned #{i}",
        url: "https://example.com/#{i}",
        pinned: true,
        published_at: i.hours.ago
      )
    end

    post pinned_entry_open_path
    json = JSON.parse(response.body)
    assert_equal 5, json["urls"].length
  end

  test "destroy requires authentication" do
    delete pinned_entry_open_path
    assert_redirected_to new_session_path
  end

  test "destroy unpins specified entries" do
    sign_in_as(@user)
    entry1 = entries(:ruby_article_one)
    entry2 = entries(:ruby_article_two)
    entry1.update!(pinned: true)
    entry2.update!(pinned: true)

    delete pinned_entry_open_path, params: { entry_ids: [ entry1.id, entry2.id ] }, as: :json
    assert_response :success

    json = JSON.parse(response.body)
    assert_equal 0, json["pinned_count"]
    assert_not entry1.reload.pinned
    assert_not entry2.reload.pinned
  end

  test "destroy only unpins specified entries" do
    sign_in_as(@user)
    entry1 = entries(:ruby_article_one)
    entry2 = entries(:ruby_article_two)
    entry1.update!(pinned: true)
    entry2.update!(pinned: true)

    delete pinned_entry_open_path, params: { entry_ids: [ entry1.id ] }, as: :json
    assert_response :success

    json = JSON.parse(response.body)
    assert_equal 1, json["pinned_count"]
    assert_not entry1.reload.pinned
    assert entry2.reload.pinned
  end
end
