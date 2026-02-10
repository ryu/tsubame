require "test_helper"

class FetchFeedsJobTest < ActiveJob::TestCase
  test "should enqueue FetchFeedJob for each feed due for fetch" do
    feed1 = feeds(:ruby_blog)
    feed1.update!(next_fetch_at: 1.minute.ago)

    feed2 = feeds(:error_feed)
    feed2.update!(next_fetch_at: 2.minutes.ago)

    feed3 = Feed.create!(url: "https://example.com/feed3.xml", next_fetch_at: 1.hour.from_now)

    assert_enqueued_jobs 2, only: FetchFeedJob do
      FetchFeedsJob.perform_now
    end
  end

  test "should not enqueue jobs for feeds with nil next_fetch_at" do
    feed = feeds(:ruby_blog)
    feed.update!(next_fetch_at: nil)

    assert_no_enqueued_jobs(only: FetchFeedJob) do
      FetchFeedsJob.perform_now
    end
  end

  test "should handle empty result set" do
    Feed.update_all(next_fetch_at: 1.hour.from_now)

    assert_no_enqueued_jobs(only: FetchFeedJob) do
      FetchFeedsJob.perform_now
    end
  end
end
