class Folder < ApplicationRecord
  has_many :feeds, dependent: :nullify

  validates :name, presence: true, uniqueness: true, length: { maximum: 50 }
end
