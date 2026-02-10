class EntriesController < ApplicationController
  def index
    @feed = Feed.find(params[:feed_id])
    @entries = @feed.entries.unread.recent
  end

  def show
    @entry = Entry.find(params[:id])
    @entry.mark_as_read!
  end

  def mark_as_read
    @entry = Entry.find(params[:id])
    was_unread = @entry.mark_as_read!
    render json: { success: true, was_unread: was_unread }
  end

  def toggle_pin
    @entry = Entry.find(params[:id])
    @entry.toggle_pin!
    @pinned_count = Entry.pinned.count
  end

  def pinned
    @entries = Entry.pinned.includes(:feed).recent
  end

  def open_pinned
    entries = Entry.pinned.includes(:feed).recent.limit(5)
    entry_ids = entries.pluck(:id)
    urls = entries.filter_map(&:safe_url)
    entries.update_all(pinned: false)
    render json: { urls: urls, entry_ids: entry_ids, pinned_count: Entry.pinned.count }
  end
end
