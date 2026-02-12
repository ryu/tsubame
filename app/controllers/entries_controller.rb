class EntriesController < ApplicationController
  def index
    @feed = Feed.find(params[:feed_id])
    @entries = @feed.entries.unread.recent
  end

  def show
    @entry = Entry.find(params[:id])
    @entry.mark_as_read!
  end

  def pinned
    @entries = Entry.pinned.includes(:feed).recent
  end
end
