class EntriesController < ApplicationController
  def index
    @feed = Feed.find(params[:feed_id])
    @entries = @feed.entries.unread.recently_published
  end

  def show
    @entry = Entry.find(params[:id])
    @entry.mark_as_read!
  end

  def pinned
    @entries = Entry.pinned.includes(:feed).recently_published
  end
end
