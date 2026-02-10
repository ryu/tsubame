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
end
