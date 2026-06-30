class EntryMarkAsReadsController < ApplicationController
  def create
    @entry = Current.user.entries.find(params[:entry_id])
    Current.user.mark_entry_as_read!(@entry)
    render turbo_stream: '<turbo-stream action="refresh"></turbo-stream>'.html_safe
  end
end
