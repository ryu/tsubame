class EntryPinsController < ApplicationController
  def create
    @entry = Current.user.entries.find(params[:entry_id])
    Current.user.toggle_entry_pin!(@entry)
    @pinned_count = Current.user.pinned_entry_count
    @pinned_entries = Current.user.pinned_entries.limit(5)
  end
end
