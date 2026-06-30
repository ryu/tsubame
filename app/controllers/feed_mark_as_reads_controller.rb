class FeedMarkAsReadsController < ApplicationController
  def create
    @feed = Current.user.feeds.find(params[:feed_id])
    Current.user.mark_feed_entries_as_read!(@feed)
    render turbo_stream: '<turbo-stream action="refresh"></turbo-stream>'.html_safe
  end
end
