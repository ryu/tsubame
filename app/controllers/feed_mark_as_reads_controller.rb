class FeedMarkAsReadsController < ApplicationController
  def create
    @feed = Current.user.feeds.find(params[:feed_id])
    Current.user.mark_feed_entries_as_read!(@feed)
    render turbo_stream: turbo_stream.refresh(request_id: nil)
  end
end
