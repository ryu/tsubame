class PinnedEntryOpensController < ApplicationController
  def destroy
    Current.user.unpin_entries!(params[:entry_ids])
    @pinned_count = Current.user.pinned_entry_count
    @pinned_entries = Current.user.pinned_entries_preview
  end
end
