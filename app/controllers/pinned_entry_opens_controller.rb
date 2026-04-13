class PinnedEntryOpensController < ApplicationController
  def destroy
    Current.user.user_entry_states.where(entry_id: Array(params[:entry_ids]), pinned: true).update_all(pinned: false)
    @pinned_count = Current.user.pinned_entry_count
    @pinned_entries = Current.user.pinned_entries.limit(5)
  end
end
