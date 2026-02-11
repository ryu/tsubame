require "test_helper"

class FeedFetchesControllerTest < ActionDispatch::IntegrationTest
  setup do
    @user = users(:one)
  end

  test "create requires authentication" do
    post feed_fetch_path(feeds(:ruby_blog))
    assert_redirected_to new_session_path
  end

  test "create performs fetch and redirects" do
    sign_in_as(@user)
    feed = feeds(:ruby_blog)

    rss_body = <<~XML
      <?xml version="1.0" encoding="UTF-8"?>
      <rss version="2.0">
        <channel>
          <title>Ruby Blog</title>
          <link>https://example.com/ruby</link>
          <item>
            <title>Test Entry</title>
            <link>https://example.com/ruby/test</link>
            <guid>test-entry-fetch-now</guid>
          </item>
        </channel>
      </rss>
    XML

    stub_request(:get, feed.url)
      .to_return(status: 200, body: rss_body, headers: { "Content-Type" => "application/rss+xml" })

    post feed_fetch_path(feed)

    assert_redirected_to feeds_path
    assert_match(/フェッチしました/, flash[:notice])
    assert feed.reload.ok?
  end

  test "create handles fetch failure gracefully" do
    sign_in_as(@user)
    feed = feeds(:ruby_blog)

    stub_request(:get, feed.url).to_return(status: 500, body: "Internal Server Error")

    post feed_fetch_path(feed)

    assert_redirected_to feeds_path
    assert feed.reload.error?
  end
end
