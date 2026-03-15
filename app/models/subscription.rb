class Subscription < ApplicationRecord
  belongs_to :user
  belongs_to :feed
  belongs_to :folder, optional: true

  validates :feed_id, uniqueness: { scope: :user_id }
  validates :rate, inclusion: { in: 0..5 }
  validate :folder_belongs_to_same_user, if: -> { folder_id.present? }

  scope :with_rate_at_least, ->(rate) { rate.to_i > 0 ? where("subscriptions.rate >= ?", rate.to_i) : all }

  scope :with_unread_count, ->(user) {
    left_joins(feed: :entries)
      .joins(sanitize_sql_array([ "LEFT JOIN user_entry_states ON user_entry_states.entry_id = entries.id AND user_entry_states.user_id = ?", user.id ]))
      .select("subscriptions.*, COUNT(CASE WHEN entries.id IS NOT NULL AND (user_entry_states.id IS NULL OR user_entry_states.read_at IS NULL) THEN 1 END) as unread_count")
      .group("subscriptions.id")
  }

  # Virtual attribute populated by with_unread_count scope
  def unread_count
    self[:unread_count] || 0
  end

  def display_title
    title.presence || feed.title || feed.url
  end

  private

  def folder_belongs_to_same_user
    unless Folder.exists?(id: folder_id, user_id: user_id)
      errors.add(:folder, "は自分のフォルダを指定してください")
    end
  end
end
