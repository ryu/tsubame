class UserEntryState < ApplicationRecord
  belongs_to :user
  belongs_to :entry

  validates :entry_id, uniqueness: { scope: :user_id }

  scope :unread, -> { where(read_at: nil) }
  scope :read, -> { where.not(read_at: nil) }
  scope :pinned, -> { where(pinned: true) }
end
