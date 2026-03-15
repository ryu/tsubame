class EntryMarkAsReadsController < ApplicationController
  def create
    @entry = Current.user.entries.find(params[:entry_id])
    was_unread = Current.user.mark_entry_as_read!(@entry)
    render json: { success: true, was_unread: was_unread }
  end
end
