require "test_helper"

class CleanupEntriesJobTest < ActiveJob::TestCase
  test "should delete entries older than 90 days that are not pinned" do
    user = users(:one)
    feed = feeds(:ruby_blog)

    # Create entry created 91 days ago, not pinned
    old_entry = feed.entries.create!(
      guid: "old-entry",
      title: "Old Entry",
      url: "https://example.com/old-entry",
      created_at: 91.days.ago
    )

    # Create entry created 89 days ago, not pinned
    recent_entry = feed.entries.create!(
      guid: "recent-entry",
      title: "Recent Entry",
      url: "https://example.com/recent-entry",
      created_at: 89.days.ago
    )

    # Create entry created 91 days ago, but pinned by a user
    old_pinned_entry = feed.entries.create!(
      guid: "old-pinned",
      title: "Old Pinned Entry",
      url: "https://example.com/old-pinned",
      created_at: 91.days.ago
    )
    UserEntryState.create!(user: user, entry: old_pinned_entry, pinned: true)

    # Create unread entry (recent)
    unread_entry = feed.entries.create!(
      guid: "unread",
      title: "Unread Entry",
      url: "https://example.com/unread"
    )

    assert_difference "Entry.count", -1 do
      CleanupEntriesJob.perform_now
    end

    # Old entry should be deleted
    assert_not Entry.exists?(old_entry.id)

    # Recent entry should still exist
    assert Entry.exists?(recent_entry.id)

    # Old pinned entry should still exist
    assert Entry.exists?(old_pinned_entry.id)

    # Unread entry should still exist
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
    # All existing entries should not meet deletion criteria
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
end
