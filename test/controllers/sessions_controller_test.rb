require "test_helper"

class SessionsControllerTest < ActionDispatch::IntegrationTest
  setup { @user = User.take }

  test "new" do
    get new_session_path
    assert_response :success
  end

  test "create with existing email creates magic link and redirects" do
    assert_difference "MagicLink.count", 1 do
      post session_path, params: { email_address: @user.email_address }
    end
    assert_redirected_to new_session_path
    assert_equal "ログインリンクをメールで送信しました。", flash[:notice]
  end

  test "create with unknown email shows same message" do
    post session_path, params: { email_address: "unknown@example.com" }
    assert_redirected_to new_session_path
    assert_equal "ログインリンクをメールで送信しました。", flash[:notice]
  end

  test "destroy" do
    sign_in_as(@user)
    delete session_path
    assert_redirected_to new_session_path
    assert_empty cookies[:session_id]
  end
end
