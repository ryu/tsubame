class Folder < ApplicationRecord
  belongs_to :user
  has_many :subscriptions, dependent: :nullify

  validates :name, presence: true, uniqueness: { scope: :user_id }, length: { maximum: 50 }
end
