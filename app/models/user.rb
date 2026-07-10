class User < ApplicationRecord
  has_many :sessions, dependent: :destroy
  has_many :magic_links, dependent: :destroy
  has_many :subscriptions, dependent: :destroy
  has_many :feeds, through: :subscriptions
  has_many :folders, dependent: :destroy
  has_many :user_entry_states, dependent: :destroy
  has_many :entries, through: :feeds
  has_one :admin, dependent: :destroy

  normalizes :email_address, with: ->(e) { e.strip.downcase }

  validates :email_address, presence: true, uniqueness: true,
                            format: { with: URI::MailTo::EMAIL_REGEXP }

  def admin?
    admin.present?
  end

  def subscribe_to(feed, folder: nil)
    subscriptions.find_or_create_by!(feed: feed) do |sub|
      sub.folder = folder
    end
  end

  def grouped_subscriptions_for_home(rate:)
    subs = subscriptions
      .with_rate_at_least(rate)
      .joins(:feed)
      .includes(:feed, :folder)
      .with_unread_count(self)
      .having("unread_count > 0")
      .order("feeds.title")

    subs.group_by(&:folder)
      .sort_by { |folder, _| folder ? [ 0, folder.name ] : [ 1, "" ] }
      .map { |folder, subscriptions| FolderGroup.new(folder:, subscriptions:) }
  end

  def entry_state_for(entry)
    user_entry_states.find_or_initialize_by(entry: entry)
  end

  def mark_entry_as_read!(entry)
    state = entry_state_for(entry)
    return false if state.read_at.present?

    now = Time.current
    state.update!(read_at: now)
    upsert_read_states(unread_duplicate_ids_for([ entry.id ]), now)
    true
  end

  def pin_entry!(entry)
    entry_state_for(entry).update!(pinned: true)
  end

  def unpin_entry!(entry)
    entry_state_for(entry).update!(pinned: false)
  end

  def unpin_entries!(entry_ids)
    user_entry_states.where(entry_id: Array(entry_ids), pinned: true).update_all(pinned: false)
  end

  def mark_feed_entries_as_read!(feed)
    unread_entry_ids = feed.entries
      .where.not(id: user_entry_states.where.not(read_at: nil).select(:entry_id))
      .pluck(:id)

    return 0 if unread_entry_ids.empty?

    now = Time.current
    upsert_read_states(unread_entry_ids, now)
    upsert_read_states(unread_duplicate_ids_for(unread_entry_ids), now)

    unread_entry_ids.size
  end

  def pinned_entry_count
    user_entry_states.pinned.count
  end

  def pinned_entries_preview
    pinned_entries.limit(5)
  end

  def pinned_entries
    Entry.joins(:user_entry_states)
      .where(user_entry_states: { user_id: id, pinned: true })
      .includes(:feed)
      .recently_published
  end

  def unread_entries_for(feed)
    read_entry_ids = user_entry_states.where.not(read_at: nil)
      .joins(:entry).where(entries: { feed_id: feed.id })
      .select(:entry_id)
    feed.entries.where.not(id: read_entry_ids).recently_published
  end

  def entry_read?(entry)
    user_entry_states.where.not(read_at: nil).exists?(entry: entry)
  end

  def entry_pinned?(entry)
    user_entry_states.exists?(entry: entry, pinned: true)
  end

  private

  # update_only で pinned に触れないことで、重複エントリーのピン状態を保持する
  def upsert_read_states(entry_ids, read_at)
    return if entry_ids.empty?

    records = entry_ids.map do |entry_id|
      { user_id: id, entry_id: entry_id, read_at: read_at, created_at: read_at, updated_at: read_at }
    end
    UserEntryState.upsert_all(records, unique_by: [ :user_id, :entry_id ], update_only: [ :read_at, :updated_at ])
  end

  # content_url が同じ別フィードの未読エントリー ID（既読の重複同期用）
  def unread_duplicate_ids_for(entry_ids)
    content_urls = Entry.where(id: entry_ids).where.not(content_url: nil).distinct.pluck(:content_url)
    return [] if content_urls.empty?

    Entry.where(content_url: content_urls)
      .where.not(id: entry_ids)
      .where.not(id: user_entry_states.where.not(read_at: nil).select(:entry_id))
      .pluck(:id)
  end
end
