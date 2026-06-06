require "test_helper"

class ContentSecurityPolicyTest < ActionDispatch::IntegrationTest
  test "enforces the content security policy" do
    get "/up"
    assert_response :success

    assert_nil response.headers["Content-Security-Policy-Report-Only"],
      "policy should be enforced, not report-only"

    policy = response.headers["Content-Security-Policy"]
    assert policy.present?, "expected an enforced policy header"
    assert_includes policy, "default-src 'self'"
    assert_includes policy, "object-src 'none'"
    assert_includes policy, "connect-src 'self' https://bookmark.hatenaapis.com"
  end
end
