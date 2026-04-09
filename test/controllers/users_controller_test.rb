require "test_helper"

class UsersControllerTest < ActionDispatch::IntegrationTest
  setup do
    @admin = users(:one)
    @non_admin = users(:two)
  end

  # -- Authentication tests --

  test "index requires authentication" do
    get users_path
    assert_redirected_to new_session_path
  end

  test "new requires authentication" do
    get new_user_path
    assert_redirected_to new_session_path
  end

  test "create requires authentication" do
    post users_path, params: { user: { email_address: "new@example.com", password: "password123" } }
    assert_redirected_to new_session_path
  end

  test "edit requires authentication" do
    get edit_user_path(@non_admin)
    assert_redirected_to new_session_path
  end

  test "update requires authentication" do
    patch user_path(@non_admin), params: { user: { email_address: "changed@example.com" } }
    assert_redirected_to new_session_path
  end

  test "destroy requires authentication" do
    delete user_path(@non_admin)
    assert_redirected_to new_session_path
  end

  # -- Admin authorization tests --

  test "index requires admin" do
    sign_in_as(@non_admin)
    get users_path
    assert_redirected_to root_path
    assert_equal "管理者権限が必要です。", flash[:alert]
  end

  test "new requires admin" do
    sign_in_as(@non_admin)
    get new_user_path
    assert_redirected_to root_path
  end

  test "create requires admin" do
    sign_in_as(@non_admin)
    assert_no_difference "User.count" do
      post users_path, params: { user: { email_address: "new@example.com", password: "password123" } }
    end
    assert_redirected_to root_path
  end

  test "edit requires admin" do
    sign_in_as(@non_admin)
    get edit_user_path(@admin)
    assert_redirected_to root_path
  end

  test "update requires admin" do
    sign_in_as(@non_admin)
    patch user_path(@admin), params: { user: { email_address: "changed@example.com" } }
    assert_redirected_to root_path
  end

  test "destroy requires admin" do
    sign_in_as(@non_admin)
    assert_no_difference "User.count" do
      delete user_path(@admin)
    end
    assert_redirected_to root_path
  end

  # -- Index --

  test "index shows user list" do
    sign_in_as(@admin)
    get users_path

    assert_response :success
    assert_select "h1", "ユーザー管理"
    assert_select "table.manage-table"
  end

  # -- New --

  test "new shows form" do
    sign_in_as(@admin)
    get new_user_path

    assert_response :success
    assert_select "input[type=email]"
    assert_select "input[type=password]"
  end

  # -- Create --

  test "create saves new user with valid params" do
    sign_in_as(@admin)

    assert_difference "User.count", 1 do
      post users_path, params: { user: { email_address: "new@example.com", password: "password123", password_confirmation: "password123" } }
    end

    assert_redirected_to users_path
    assert_equal "ユーザーを作成しました。", flash[:notice]
  end

  test "create with admin flag creates admin record" do
    sign_in_as(@admin)

    assert_difference [ "User.count", "Admin.count" ], 1 do
      post users_path, params: { user: { email_address: "newadmin@example.com", password: "password123", password_confirmation: "password123" }, admin: "1" }
    end

    assert User.find_by(email_address: "newadmin@example.com").admin?
  end

  test "create fails with blank email" do
    sign_in_as(@admin)

    assert_no_difference "User.count" do
      post users_path, params: { user: { email_address: "", password: "password123", password_confirmation: "password123" } }
    end

    assert_response :unprocessable_entity
  end

  test "create fails with duplicate email" do
    sign_in_as(@admin)

    assert_no_difference "User.count" do
      post users_path, params: { user: { email_address: @admin.email_address, password: "password123", password_confirmation: "password123" } }
    end

    assert_response :unprocessable_entity
  end

  test "create fails with password confirmation mismatch" do
    sign_in_as(@admin)

    assert_no_difference "User.count" do
      post users_path, params: { user: { email_address: "new@example.com", password: "password123", password_confirmation: "different" } }
    end

    assert_response :unprocessable_entity
  end

  test "create fails with short password" do
    sign_in_as(@admin)

    assert_no_difference "User.count" do
      post users_path, params: { user: { email_address: "new@example.com", password: "short", password_confirmation: "short" } }
    end

    assert_response :unprocessable_entity
  end

  # -- Edit --

  test "edit shows user form" do
    sign_in_as(@admin)
    get edit_user_path(@non_admin)

    assert_response :success
    assert_select "input[type=email]"
  end

  # -- Update --

  test "update saves changes with valid params" do
    sign_in_as(@admin)

    patch user_path(@non_admin), params: { user: { email_address: "changed@example.com" } }

    assert_redirected_to users_path
    assert_equal "ユーザーを更新しました。", flash[:notice]
    assert_equal "changed@example.com", @non_admin.reload.email_address
  end

  test "update without password keeps existing password" do
    sign_in_as(@admin)

    patch user_path(@non_admin), params: { user: { email_address: @non_admin.email_address, password: "", password_confirmation: "" } }

    assert_redirected_to users_path
    assert @non_admin.reload.authenticate("password")
  end

  test "update with new password changes password" do
    sign_in_as(@admin)

    patch user_path(@non_admin), params: { user: { email_address: @non_admin.email_address, password: "newpassword123", password_confirmation: "newpassword123" } }

    assert_redirected_to users_path
    assert @non_admin.reload.authenticate("newpassword123")
  end

  test "update can grant admin" do
    sign_in_as(@admin)

    patch user_path(@non_admin), params: { user: { email_address: @non_admin.email_address }, admin: "1" }

    assert_redirected_to users_path
    assert @non_admin.reload.admin?
  end

  test "update can revoke admin" do
    sign_in_as(@admin)
    @non_admin.create_admin

    patch user_path(@non_admin), params: { user: { email_address: @non_admin.email_address } }

    assert_redirected_to users_path
    assert_not @non_admin.reload.admin?
  end

  test "update cannot revoke own admin" do
    sign_in_as(@admin)

    patch user_path(@admin), params: { user: { email_address: @admin.email_address } }

    assert_redirected_to users_path
    assert @admin.reload.admin?
  end

  test "update fails with blank email" do
    sign_in_as(@admin)

    patch user_path(@non_admin), params: { user: { email_address: "" } }

    assert_response :unprocessable_entity
  end

  # -- Destroy --

  test "destroy deletes user and redirects" do
    sign_in_as(@admin)

    assert_difference "User.count", -1 do
      delete user_path(@non_admin)
    end

    assert_redirected_to users_path
    assert_equal "ユーザーを削除しました。", flash[:notice]
  end

  test "destroy prevents self-deletion" do
    sign_in_as(@admin)

    assert_no_difference "User.count" do
      delete user_path(@admin)
    end

    assert_redirected_to users_path
    assert_equal "自分自身は削除できません。", flash[:alert]
  end
end
