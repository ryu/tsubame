class HomeController < ApplicationController
  def index
    # Fetch feeds with unread count in a single query (N+1 prevention)
    @feeds = Feed.left_joins(:entries)
      .select("feeds.*, COUNT(CASE WHEN entries.id IS NOT NULL AND entries.read_at IS NULL THEN 1 END) as unread_count")
      .group("feeds.id")
      .order(:title)
    @pinned_count = Entry.pinned.count
  end
end
