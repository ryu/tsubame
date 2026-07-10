class EntryPinsController < ApplicationController
  before_action :set_entry

  def create
    Current.user.pin_entry!(@entry)
    load_pinned
  end

  def destroy
    Current.user.unpin_entry!(@entry)
    load_pinned
    render :create
  end

  private

  def set_entry
    @entry = Current.user.entries.find(params[:entry_id])
  end

  def load_pinned
    @pinned_count = Current.user.pinned_entry_count
    @pinned_entries = Current.user.pinned_entries_preview
  end
end
