require "test_helper"

class CleanupEntriesJobTest < ActiveJob::TestCase
  test "should delete entries older than 90 days that are not pinned" do
    user = users(:one)
    feed = feeds(:ruby_blog)

    old_entry = feed.entries.create!(
      guid: "old-entry",
      title: "Old Entry",
      url: "https://example.com/old-entry",
      created_at: 91.days.ago
    )

    recent_entry = feed.entries.create!(
      guid: "recent-entry",
      title: "Recent Entry",
      url: "https://example.com/recent-entry",
      created_at: 89.days.ago
    )

    old_pinned_entry = feed.entries.create!(
      guid: "old-pinned",
      title: "Old Pinned Entry",
      url: "https://example.com/old-pinned",
      created_at: 91.days.ago
    )
    UserEntryState.create!(user: user, entry: old_pinned_entry, pinned: true)

    unread_entry = feed.entries.create!(
      guid: "unread",
      title: "Unread Entry",
      url: "https://example.com/unread"
    )

    assert_difference "Entry.count", -1 do
      CleanupEntriesJob.perform_now
    end

    assert_not Entry.exists?(old_entry.id)

    assert Entry.exists?(recent_entry.id)

    assert Entry.exists?(old_pinned_entry.id)

    assert Entry.exists?(unread_entry.id)
  end

  test "should not delete recent entries" do
    feed = feeds(:ruby_blog)

    entry = feed.entries.create!(
      guid: "recent",
      title: "Recent",
      url: "https://example.com/recent"
    )

    assert_no_difference "Entry.count" do
      CleanupEntriesJob.perform_now
    end

    assert Entry.exists?(entry.id)
  end

  test "should handle no entries to delete" do
    assert_no_difference "Entry.count" do
      CleanupEntriesJob.perform_now
    end
  end

  test "should delete multiple old entries" do
    feed = feeds(:ruby_blog)

    5.times do |i|
      feed.entries.create!(
        guid: "old-entry-#{i}",
        title: "Old Entry #{i}",
        url: "https://example.com/old-#{i}",
        created_at: 100.days.ago
      )
    end

    assert_difference "Entry.count", -5 do
      CleanupEntriesJob.perform_now
    end
  end

  test "should delete across multiple batches via the cursor" do
    feed = feeds(:ruby_blog)

    3.times do |i|
      feed.entries.create!(
        guid: "batch-#{i}",
        title: "Batch Entry #{i}",
        url: "https://example.com/batch-#{i}",
        created_at: 100.days.ago
      )
    end

    with_batch_size(2) do
      assert_difference "Entry.count", -3 do
        CleanupEntriesJob.perform_now
      end
    end
  end

  private

  def with_batch_size(size)
    original = CleanupEntriesJob::BATCH_SIZE
    CleanupEntriesJob.send(:remove_const, :BATCH_SIZE)
    CleanupEntriesJob.const_set(:BATCH_SIZE, size)
    yield
  ensure
    CleanupEntriesJob.send(:remove_const, :BATCH_SIZE)
    CleanupEntriesJob.const_set(:BATCH_SIZE, original)
  end
end
