class EntryMarkAsReadsController < ApplicationController
  def create
    @entry = Current.user.entries.find(params[:entry_id])
    Current.user.mark_entry_as_read!(@entry)
    render turbo_stream: turbo_stream.refresh(request_id: nil)
  end
end
