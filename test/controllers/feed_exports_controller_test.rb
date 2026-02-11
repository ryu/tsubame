require "test_helper"

class FeedExportsControllerTest < ActionDispatch::IntegrationTest
  setup do
    @user = users(:one)
  end

  test "show requires authentication" do
    get feed_export_path
    assert_redirected_to new_session_path
  end

  test "show returns OPML file" do
    sign_in_as(@user)

    get feed_export_path
    assert_response :success
    assert_equal "application/xml", response.media_type
    assert_match /attachment/, response.headers["Content-Disposition"]
    assert_match /subscriptions\.opml/, response.headers["Content-Disposition"]
    assert_match /<opml version=['"]1\.0['"]>/, response.body
  end
end
