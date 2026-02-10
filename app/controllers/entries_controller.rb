class EntriesController < ApplicationController
  def index
    @feed = Feed.find(params[:feed_id])
    @entries = @feed.entries.recent
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
    render json: { success: true, pinned: @entry.pinned }
  end
end
