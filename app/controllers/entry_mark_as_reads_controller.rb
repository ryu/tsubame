class EntryMarkAsReadsController < ApplicationController
  def create
    @entry = Current.user.entries.find(params[:entry_id])
    Current.user.mark_entry_as_read!(@entry)
    # request_id を付けると要求元クライアント自身の refresh が抑止されるため nil にする
    render turbo_stream: turbo_stream.refresh(request_id: nil)
  end
end
