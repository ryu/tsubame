class EntryMarkAsReadsController < ApplicationController
  def create
    @entry = Entry.find(params[:entry_id])
    was_unread = @entry.mark_as_read!
    render json: { success: true, was_unread: was_unread }
  end
end
