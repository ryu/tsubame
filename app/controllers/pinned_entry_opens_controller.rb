class PinnedEntryOpensController < ApplicationController
  def create
    entries = Entry.pinned.includes(:feed).recently_published.limit(5)
    entry_ids = entries.pluck(:id)
    urls = entries.filter_map(&:safe_url_for_link)
    entries.update_all(pinned: false)
    render json: { urls: urls, entry_ids: entry_ids, pinned_count: Entry.pinned.count }
  end
end
