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

  test "the first request without a session cookie gets a usable nonce" do
    get new_session_path
    assert_response :success

    assert_equal nonce_from_header, nonce_from_meta_tag
    assert nonce_from_header.present?, "expected a non-empty nonce"
    assert_includes response.body, %(<script type="module" nonce="#{nonce_from_header}">import "application"</script>)
  end

  test "the nonce stays stable across requests" do
    get new_session_path
    first = nonce_from_header

    get new_session_path
    assert_equal first, nonce_from_header
  end

  private
    def nonce_from_header
      response.headers["Content-Security-Policy"][/script-src [^;]*'nonce-([^']*)'/, 1]
    end

    def nonce_from_meta_tag
      response.body[/<meta name="csp-nonce" content="([^"]*)"/, 1]
    end
end
