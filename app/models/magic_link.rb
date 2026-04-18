class MagicLink < ApplicationRecord
  belongs_to :user

  scope :valid, -> { where("expires_at > ?", Time.current) }

  def self.generate_for(user)
    token = SecureRandom.urlsafe_base64(32)
    create!(user: user, token_digest: digest(token), expires_at: 15.minutes.from_now)
    token
  end

  def self.find_by_token(token)
    valid.find_by(token_digest: digest(token))
  end

  class << self
    private

    def digest(token) = Digest::SHA256.hexdigest(token)
  end
end
