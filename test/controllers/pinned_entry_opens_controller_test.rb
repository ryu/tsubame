require "test_helper"

class PinnedEntryOpensControllerTest < ActionDispatch::IntegrationTest
  setup do
    @user = users(:one)
  end

  test "destroy requires authentication" do
    delete pinned_entry_open_path
    assert_redirected_to new_session_path
  end

  test "destroy unpins specified entries" do
    sign_in_as(@user)
    entry1 = entries(:ruby_article_one)
    entry2 = entries(:ruby_article_two)

    @user.entry_state_for(entry1).update!(pinned: true)
    @user.entry_state_for(entry2).update!(pinned: true)

    delete pinned_entry_open_path,
      params: { entry_ids: [ entry1.id, entry2.id ] },
      headers: { "Accept" => "text/vnd.turbo-stream.html" },
      as: :json
    assert_response :success

    assert_not @user.entry_pinned?(entry1)
    assert_not @user.entry_pinned?(entry2)
    assert_match "pin_badge", response.body
  end

  test "destroy only unpins specified entries" do
    sign_in_as(@user)
    entry1 = entries(:ruby_article_one)
    entry2 = entries(:ruby_article_two)

    @user.entry_state_for(entry1).update!(pinned: true)
    @user.entry_state_for(entry2).update!(pinned: true)

    delete pinned_entry_open_path,
      params: { entry_ids: [ entry1.id ] },
      headers: { "Accept" => "text/vnd.turbo-stream.html" },
      as: :json
    assert_response :success

    assert_not @user.entry_pinned?(entry1)
    assert @user.entry_pinned?(entry2)
  end
end
