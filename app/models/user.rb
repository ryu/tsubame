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

  def invalidate_other_sessions!(except:)
    sessions.where.not(id: except).destroy_all
  end

  # Subscribe to a feed. Returns existing subscription if already subscribed.
  def subscribe_to(feed, folder: nil)
    subscriptions.find_or_create_by!(feed: feed) do |sub|
      sub.folder = folder
    end
  end

  # Subscribed feeds grouped by folder with unread counts for the home screen.
  # Returns FolderGroup objects sorted by folder name, with nil (unclassified) last.
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

  # Find or initialize a UserEntryState for an entry
  def entry_state_for(entry)
    user_entry_states.find_or_initialize_by(entry: entry)
  end

  # Mark an entry as read. Returns true if newly marked.
  def mark_entry_as_read!(entry)
    state = entry_state_for(entry)
    return false if state.read_at.present?

    now = Time.current
    state.update!(read_at: now)
    sync_read_state_to_duplicates!(entry, now)
    true
  end

  # Toggle pin on an entry
  def toggle_entry_pin!(entry)
    state = entry_state_for(entry)
    state.update!(pinned: !state.pinned)
    state
  end

  # Mark all entries of a feed as read
  def mark_feed_entries_as_read!(feed)
    unread_entry_ids = feed.entries
      .where.not(id: user_entry_states.where.not(read_at: nil).select(:entry_id))
      .pluck(:id)

    return 0 if unread_entry_ids.empty?

    now = Time.current
    records = unread_entry_ids.map do |entry_id|
      { user_id: id, entry_id: entry_id, read_at: now, created_at: now, updated_at: now }
    end
    UserEntryState.upsert_all(records, unique_by: [ :user_id, :entry_id ], update_only: [ :read_at, :updated_at ])

    content_urls = Entry.where(id: unread_entry_ids).where.not(content_url: nil).pluck(:content_url).uniq
    if content_urls.any?
      duplicate_entry_ids = Entry.where(content_url: content_urls)
        .where.not(id: unread_entry_ids)
        .where.not(id: user_entry_states.where.not(read_at: nil).select(:entry_id))
        .pluck(:id)

      if duplicate_entry_ids.any?
        dup_records = duplicate_entry_ids.map do |entry_id|
          { user_id: id, entry_id: entry_id, read_at: now, created_at: now, updated_at: now }
        end
        UserEntryState.upsert_all(dup_records, unique_by: [ :user_id, :entry_id ], update_only: [ :read_at, :updated_at ])
      end
    end

    unread_entry_ids.size
  end

  # Count of pinned entries for the current user
  def pinned_entry_count
    user_entry_states.pinned.count
  end

  # Pinned entries with associated feed
  def pinned_entries
    Entry.joins(:user_entry_states)
      .where(user_entry_states: { user_id: id, pinned: true })
      .includes(:feed)
      .recently_published
  end

  # Unread entries for a feed
  def unread_entries_for(feed)
    read_entry_ids = user_entry_states.where.not(read_at: nil)
      .joins(:entry).where(entries: { feed_id: feed.id })
      .select(:entry_id)
    feed.entries.where.not(id: read_entry_ids).recently_published
  end

  # Check if an entry is read
  def entry_read?(entry)
    user_entry_states.where.not(read_at: nil).exists?(entry: entry)
  end

  # Check if an entry is pinned
  def entry_pinned?(entry)
    user_entry_states.exists?(entry: entry, pinned: true)
  end

  private

  def sync_read_state_to_duplicates!(entry, read_at)
    return if entry.content_url.blank?

    duplicate_ids = Entry.duplicates_of(entry)
      .where.not(id: user_entry_states.where.not(read_at: nil).select(:entry_id))
      .pluck(:id)

    return if duplicate_ids.empty?

    records = duplicate_ids.map do |entry_id|
      { user_id: id, entry_id: entry_id, read_at: read_at, created_at: read_at, updated_at: read_at }
    end
    UserEntryState.upsert_all(records, unique_by: [ :user_id, :entry_id ], update_only: [ :read_at, :updated_at ])
  end
end
