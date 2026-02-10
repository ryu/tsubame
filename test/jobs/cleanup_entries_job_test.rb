require "test_helper"

class CleanupEntriesJobTest < ActiveJob::TestCase
  test "should delete entries read more than 90 days ago and not pinned" do
    feed = feeds(:ruby_blog)

    # Create entry read 91 days ago, not pinned
    old_read_entry = feed.entries.create!(
      guid: "old-read",
      title: "Old Read Entry",
      url: "https://example.com/old-read",
      read_at: 91.days.ago
    )

    # Create entry read 89 days ago, not pinned
    recent_read_entry = feed.entries.create!(
      guid: "recent-read",
      title: "Recent Read Entry",
      url: "https://example.com/recent-read",
      read_at: 89.days.ago
    )

    # Create entry read 91 days ago, but pinned
    old_pinned_entry = feed.entries.create!(
      guid: "old-pinned",
      title: "Old Pinned Entry",
      url: "https://example.com/old-pinned",
      read_at: 91.days.ago,
      pinned: true
    )

    # Create unread entry
    unread_entry = feed.entries.create!(
      guid: "unread",
      title: "Unread Entry",
      url: "https://example.com/unread"
    )

    assert_difference "Entry.count", -1 do
      CleanupEntriesJob.perform_now
    end

    # Old read entry should be deleted
    assert_not Entry.exists?(old_read_entry.id)

    # Recent read entry should still exist
    assert Entry.exists?(recent_read_entry.id)

    # Old pinned entry should still exist
    assert Entry.exists?(old_pinned_entry.id)

    # Unread entry should still exist
    assert Entry.exists?(unread_entry.id)
  end

  test "should not delete entries with nil read_at" do
    feed = feeds(:ruby_blog)

    entry = feed.entries.create!(
      guid: "never-read",
      title: "Never Read",
      url: "https://example.com/never-read",
      read_at: nil
    )

    assert_no_difference "Entry.count" do
      CleanupEntriesJob.perform_now
    end

    assert Entry.exists?(entry.id)
  end

  test "should handle no entries to delete" do
    # All existing entries should not meet deletion criteria
    assert_no_difference "Entry.count" do
      CleanupEntriesJob.perform_now
    end
  end

  test "should delete multiple old read entries" do
    feed = feeds(:ruby_blog)

    5.times do |i|
      feed.entries.create!(
        guid: "old-entry-#{i}",
        title: "Old Entry #{i}",
        url: "https://example.com/old-#{i}",
        read_at: 100.days.ago
      )
    end

    assert_difference "Entry.count", -5 do
      CleanupEntriesJob.perform_now
    end
  end
end
