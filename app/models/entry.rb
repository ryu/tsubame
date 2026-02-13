class Entry < ApplicationRecord
  include Entry::RssParser

  belongs_to :feed

  validates :guid, presence: true, uniqueness: { scope: :feed_id }

  scope :unread, -> { where(read_at: nil) }
  scope :pinned, -> { where(pinned: true) }
  scope :recently_published, -> { order(published_at: :desc) }

  # Mark entry as read (idempotent)
  # Returns true if marked as read for the first time, false if already read
  def mark_as_read!
    return false if read_at.present?
    update!(read_at: Time.current)
    true
  end

  def toggle_pin!
    update!(pinned: !pinned)
  end

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
