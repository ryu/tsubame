class PinnedEntryOpensController < ApplicationController
  def create
    entries = Current.user.pinned_entries.limit(5)
    entry_ids = entries.pluck("entries.id")
    urls = entries.filter_map(&:safe_url_for_link)
    render json: { urls: urls, entry_ids: entry_ids }
  end

  def destroy
    Current.user.user_entry_states.where(entry_id: Array(params[:entry_ids]), pinned: true).update_all(pinned: false)
    render json: { pinned_count: Current.user.pinned_entry_count }
  end
end
