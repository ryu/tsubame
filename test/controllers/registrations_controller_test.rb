require "test_helper"

class RegistrationsControllerTest < ActionDispatch::IntegrationTest
  test "new shows registration form" do
    get new_registration_path
    assert_response :success
    assert_select "h2", "新規登録"
    assert_select "input[type=email]"
    assert_select "input[type=password]", count: 2
  end

  test "create registers user and signs in" do
    assert_difference "User.count", 1 do
      post registration_path, params: {
        user: {
          email_address: "new@example.com",
          password: "password123",
          password_confirmation: "password123"
        }
      }
    end

    assert_redirected_to root_path
    assert_equal "アカウントを作成しました。", flash[:notice]

    user = User.find_by(email_address: "new@example.com")
    assert_not_nil user
    assert cookies[:session_id].present?
  end

  test "create rejects mismatched password confirmation" do
    assert_no_difference "User.count" do
      post registration_path, params: {
        user: {
          email_address: "new@example.com",
          password: "password123",
          password_confirmation: "different"
        }
      }
    end

    assert_response :unprocessable_entity
  end

  test "create rejects duplicate email" do
    assert_no_difference "User.count" do
      post registration_path, params: {
        user: {
          email_address: users(:one).email_address,
          password: "password123",
          password_confirmation: "password123"
        }
      }
    end

    assert_response :unprocessable_entity
  end

  test "create rejects blank email" do
    assert_no_difference "User.count" do
      post registration_path, params: {
        user: {
          email_address: "",
          password: "password123",
          password_confirmation: "password123"
        }
      }
    end

    assert_response :unprocessable_entity
  end

  test "login page links to registration" do
    get new_session_path
    assert_select "a[href='#{new_registration_path}']"
  end

  test "registration page links to login" do
    get new_registration_path
    assert_select "a[href='#{new_session_path}']"
  end
end
