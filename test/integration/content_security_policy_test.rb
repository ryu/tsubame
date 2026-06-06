require "test_helper"

class ContentSecurityPolicyTest < ActionDispatch::IntegrationTest
  test "sends the content security policy in report-only mode" do
    get "/up"
    assert_response :success

    assert_nil response.headers["Content-Security-Policy"],
      "policy should not be enforced yet"

    policy = response.headers["Content-Security-Policy-Report-Only"]
    assert policy.present?, "expected a report-only policy header"
    assert_includes policy, "default-src 'self'"
    assert_includes policy, "object-src 'none'"
    assert_includes policy, "connect-src 'self' https://bookmark.hatenaapis.com"
  end
end
