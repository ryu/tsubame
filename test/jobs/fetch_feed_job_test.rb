require "test_helper"

class FetchFeedJobTest < ActiveJob::TestCase
  test "perform fetches feed and creates entries" do
    feed = feeds(:ruby_blog)
    feed.update!(url: "https://example.com/feed.xml", etag: nil, last_modified: nil, status: :ok, error_message: nil)

    rss_content = <<~RSS
      <?xml version="1.0"?>
      <rss version="2.0">
        <channel>
          <title>Example Feed</title>
          <item>
            <guid>https://example.com/job-entry</guid>
            <title>Job Entry</title>
            <link>https://example.com/job-entry</link>
            <description>Created via job</description>
          </item>
        </channel>
      </rss>
    RSS

    stub_request(:get, "https://example.com/feed.xml")
      .to_return(status: 200, body: rss_content)

    assert_difference -> { feed.entries.count }, 1 do
      FetchFeedJob.perform_now(feed.id)
    end

    feed.reload
    assert feed.ok?
  end

  test "perform with non-existent feed_id does not raise" do
    assert_nothing_raised do
      FetchFeedJob.perform_now(999999)
    end
  end
end
