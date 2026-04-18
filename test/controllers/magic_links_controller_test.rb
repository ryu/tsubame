require "test_helper"

class MagicLinksControllerTest < ActionDispatch::IntegrationTest
  setup { @user = User.take }

  test "show with valid token starts session" do
    token = MagicLink.generate_for(@user)
    get magic_link_path(token)
    assert_redirected_to root_path
    assert cookies[:session_id]
  end

  test "show with expired token redirects with alert" do
    token = MagicLink.generate_for(@user)
    travel 16.minutes do
      get magic_link_path(token)
    end
    assert_redirected_to new_session_path
    assert_equal "リンクが無効または期限切れです。再度メールを送信してください。", flash[:alert]
  end

  test "show with invalid token redirects with alert" do
    get magic_link_path("invalidtoken")
    assert_redirected_to new_session_path
    assert_equal "リンクが無効または期限切れです。再度メールを送信してください。", flash[:alert]
  end

  test "show destroys token after use" do
    token = MagicLink.generate_for(@user)
    get magic_link_path(token)
    assert_nil MagicLink.find_by_token(token)
  end
end
