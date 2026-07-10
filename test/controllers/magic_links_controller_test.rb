require "test_helper"

class MagicLinksControllerTest < ActionDispatch::IntegrationTest
  setup { @user = User.take }

  test "show renders login button without consuming token" do
    token = MagicLink.generate_for(@user)
    get magic_link_path(token)

    assert_response :success
    assert_select "form[action=?]", magic_link_consumption_path(token)
    assert_not_nil MagicLink.find_by_token(token)
    assert_nil cookies[:session_id].presence
  end

  test "consumption with valid token starts session" do
    token = MagicLink.generate_for(@user)
    post magic_link_consumption_path(token)

    assert_redirected_to root_path
    assert cookies[:session_id]
  end

  test "consumption destroys token after use" do
    token = MagicLink.generate_for(@user)
    post magic_link_consumption_path(token)

    assert_nil MagicLink.find_by_token(token)
  end

  test "consumption with expired token redirects with alert" do
    token = MagicLink.generate_for(@user)
    travel 16.minutes do
      post magic_link_consumption_path(token)
    end
    assert_redirected_to new_session_path
    assert_equal "リンクが無効または期限切れです。再度メールを送信してください。", flash[:alert]
  end

  test "consumption with invalid token redirects with alert" do
    post magic_link_consumption_path("invalidtoken")
    assert_redirected_to new_session_path
    assert_equal "リンクが無効または期限切れです。再度メールを送信してください。", flash[:alert]
  end
end
