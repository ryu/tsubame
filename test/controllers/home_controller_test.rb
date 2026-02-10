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

  test "home page links to feed entries" do
    sign_in_as(users(:one))

    get root_url
    assert_response :success
    assert_select "a[href='#{feed_entries_path(feeds(:ruby_blog))}']"
  end
end
