require "test_helper"

class PasswordsControllerTest < ActionDispatch::IntegrationTest
  setup do
    @user = users(:one)
    sign_in_as(@user)
  end

  test "edit shows form when authenticated" do
    get edit_password_path
    assert_response :success
  end

  test "edit redirects when unauthenticated" do
    sign_out
    get edit_password_path
    assert_redirected_to new_session_path
  end

  test "update changes password with correct challenge" do
    patch password_path, params: { user: {
      password_challenge: "password",
      password: "new_password",
      password_confirmation: "new_password"
    } }

    assert_redirected_to root_path
    assert @user.reload.authenticate("new_password")
  end

  test "update fails with wrong challenge" do
    patch password_path, params: { user: {
      password_challenge: "wrong",
      password: "new_password",
      password_confirmation: "new_password"
    } }

    assert_response :unprocessable_entity
    assert @user.reload.authenticate("password")
  end

  test "update fails with mismatched confirmation" do
    patch password_path, params: { user: {
      password_challenge: "password",
      password: "new_password",
      password_confirmation: "different"
    } }

    assert_response :unprocessable_entity
    assert @user.reload.authenticate("password")
  end

  test "update invalidates other sessions but keeps current" do
    other_session = @user.sessions.create!
    current_session_id = Current.session.id

    patch password_path, params: { user: {
      password_challenge: "password",
      password: "new_password",
      password_confirmation: "new_password"
    } }

    assert_redirected_to root_path
    assert_not Session.exists?(other_session.id)
    assert Session.exists?(current_session_id)
  end
end
