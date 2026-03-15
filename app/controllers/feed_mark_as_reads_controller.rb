class FeedMarkAsReadsController < ApplicationController
  def create
    @feed = Current.user.feeds.find(params[:feed_id])
    count = Current.user.mark_feed_entries_as_read!(@feed)
    render json: { success: true, marked_count: count }
  end
end
