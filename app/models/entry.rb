class Entry < ApplicationRecord
  belongs_to :feed

  validates :guid, presence: true, uniqueness: { scope: :feed_id }

  scope :unread, -> { where(read_at: nil) }
  scope :pinned, -> { where(pinned: true) }
  scope :recent, -> { order(published_at: :desc) }
end
