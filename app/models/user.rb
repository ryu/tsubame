class User < ApplicationRecord
  has_secure_password
  has_many :sessions, dependent: :destroy

  normalizes :email_address, with: ->(e) { e.strip.downcase }

  def invalidate_other_sessions!(except:)
    sessions.where.not(id: except).destroy_all
  end
end
