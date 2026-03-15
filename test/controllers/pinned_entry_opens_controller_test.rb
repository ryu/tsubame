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

    # Set up pinned states via UserEntryState
    state1 = @user.entry_state_for(entry1)
    state1.update!(pinned: true)
    entry1.update!(url: "https://example.com/1")

    state2 = @user.entry_state_for(entry2)
    state2.update!(pinned: true)
    entry2.update!(url: "https://example.com/2")

    post pinned_entry_open_path
    assert_response :success

    json = JSON.parse(response.body)
    assert_equal 2, json["urls"].length
    assert_includes json["urls"], "https://example.com/1"
    assert_includes json["urls"], "https://example.com/2"
    assert_equal 2, json["entry_ids"].length

    # Entries should still be pinned
    assert @user.entry_pinned?(entry1), "entry should still be pinned"
    assert @user.entry_pinned?(entry2), "entry should still be pinned"
  end

  test "create handles no pinned entries" do
    sign_in_as(@user)
    @user.user_entry_states.update_all(pinned: false)

    post pinned_entry_open_path
    assert_response :success

    json = JSON.parse(response.body)
    assert_equal 0, json["urls"].length
  end

  test "create limits to 5 entries" do
    sign_in_as(@user)
    feed = feeds(:ruby_blog)
    # Clear existing pinned states
    @user.user_entry_states.update_all(pinned: false)

    6.times do |i|
      entry = feed.entries.create!(
        guid: "pin-test-#{i}",
        title: "Pinned #{i}",
        url: "https://example.com/#{i}",
        published_at: i.hours.ago
      )
      @user.user_entry_states.create!(entry: entry, pinned: true)
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

    # Set up pinned states
    state1 = @user.entry_state_for(entry1)
    state1.update!(pinned: true)
    state2 = @user.entry_state_for(entry2)
    state2.update!(pinned: true)

    delete pinned_entry_open_path, params: { entry_ids: [ entry1.id, entry2.id ] }, as: :json
    assert_response :success

    json = JSON.parse(response.body)
    assert_equal 0, json["pinned_count"]
    assert_not @user.entry_pinned?(entry1)
    assert_not @user.entry_pinned?(entry2)
  end

  test "destroy only unpins specified entries" do
    sign_in_as(@user)
    entry1 = entries(:ruby_article_one)
    entry2 = entries(:ruby_article_two)

    # Set up pinned states
    state1 = @user.entry_state_for(entry1)
    state1.update!(pinned: true)
    state2 = @user.entry_state_for(entry2)
    state2.update!(pinned: true)

    delete pinned_entry_open_path, params: { entry_ids: [ entry1.id ] }, as: :json
    assert_response :success

    json = JSON.parse(response.body)
    assert_equal 1, json["pinned_count"]
    assert_not @user.entry_pinned?(entry1)
    assert @user.entry_pinned?(entry2)
  end
end
