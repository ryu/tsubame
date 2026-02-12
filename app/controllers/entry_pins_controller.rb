class EntryPinsController < ApplicationController
  def create
    @entry = Entry.find(params[:entry_id])
    @entry.toggle_pin!
    @pinned_count = Entry.pinned.count
  end
end
