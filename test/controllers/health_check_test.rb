require "test_helper"

class HealthCheckTest < ActionDispatch::IntegrationTest
  test "health check is accessible without authentication" do
    get rails_health_check_url
    assert_response :success
  end
end
