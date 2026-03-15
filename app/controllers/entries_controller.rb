class EntriesController < ApplicationController
  def index
    @feed = Current.user.feeds.find(params[:feed_id])
    @entries = Current.user.unread_entries_for(@feed)
    @entry_states = load_entry_states(@entries)
  end

  def show
    @entry = Current.user.entries.find(params[:id])
    Current.user.mark_entry_as_read!(@entry)
    @pinned = Current.user.entry_pinned?(@entry)
  end

  def pinned
    @entries = Current.user.pinned_entries
    @entry_states = load_entry_states(@entries)
  end

  private

  def load_entry_states(entries)
    entry_ids = entries.map(&:id)
    states = Current.user.user_entry_states.where(entry_id: entry_ids).index_by(&:entry_id)
    entry_ids.each_with_object({}) do |id, hash|
      state = states[id]
      hash[id] = {
        read: state&.read_at.present?,
        pinned: state&.pinned || false
      }
    end
  end
end
