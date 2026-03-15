class Entry < ApplicationRecord
  include Entry::RssParser

  belongs_to :feed
  has_many :user_entry_states, dependent: :destroy

  validates :guid, presence: true, uniqueness: { scope: :feed_id }

  scope :recently_published, -> { order(published_at: :desc) }

  # Returns sanitized URL safe for use in link hrefs.
  # Returns nil if URL is blank or not HTTP(S).
  def safe_url_for_link
    return nil if url.blank?

    uri = URI.parse(url)
    return nil unless uri.is_a?(URI::HTTP) || uri.is_a?(URI::HTTPS)

    url
  rescue URI::InvalidURIError
    nil
  end
end
