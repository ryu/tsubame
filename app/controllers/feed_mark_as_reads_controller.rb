class FeedMarkAsReadsController < ApplicationController
  def create
    @feed = Feed.find(params[:feed_id])
    count = @feed.mark_all_entries_as_read!
    render json: { success: true, marked_count: count }
  end
end
