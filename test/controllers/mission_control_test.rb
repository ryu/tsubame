require "test_helper"

class MissionControlTest < ActionDispatch::IntegrationTest
  setup do
    @admin = users(:one)
    @non_admin = users(:two)
  end

  test "jobs dashboard requires authentication" do
    get "/jobs"
    assert_redirected_to "/session/new"
  end

  test "jobs dashboard requires admin" do
    sign_in_as(@non_admin)
    get "/jobs"
    assert_redirected_to "/"
    assert_equal "管理者権限が必要です。", flash[:alert]
  end

  test "jobs dashboard is accessible to admin" do
    sign_in_as(@admin)
    get "/jobs"
    assert_response :success
  end
end
