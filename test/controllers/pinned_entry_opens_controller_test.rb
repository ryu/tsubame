require "test_helper"

class PinnedEntryOpensControllerTest < ActionDispatch::IntegrationTest
  setup do
    @user = users(:one)
  end

  test "create requires authentication" do
    post pinned_entry_open_path
    assert_redirected_to new_session_path
  end

  test "create returns URLs and unpins entries" do
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
    assert_equal 0, json["pinned_count"]
    assert_not entry1.reload.pinned
    assert_not entry2.reload.pinned
  end

  test "create handles no pinned entries" do
    sign_in_as(@user)
    Entry.update_all(pinned: false)

    post pinned_entry_open_path
    assert_response :success

    json = JSON.parse(response.body)
    assert_equal 0, json["urls"].length
    assert_equal 0, json["pinned_count"]
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
end
