class Feed < ApplicationRecord
  include Feed::Fetching
  include Feed::Opml

  has_many :entries, dependent: :destroy

  enum :status, { ok: 0, error: 1 }, default: :ok

  validates :url, presence: true, uniqueness: true
  validate :url_must_be_http, if: -> { url.present? }

  normalizes :url, with: ->(url) { url.strip.gsub(/&(amp;)+/, "&") }

  FETCH_INTERVAL_OPTIONS = {
    10   => "10分",
    30   => "30分",
    60   => "1時間",
    180  => "3時間",
    360  => "6時間",
    720  => "12時間",
    1440 => "24時間"
  }.freeze

  ERROR_BACKOFF_MINUTES = 30

  validates :fetch_interval_minutes, inclusion: { in: FETCH_INTERVAL_OPTIONS.keys }

  after_save_commit :recalculate_next_fetch_at, if: :saved_change_to_fetch_interval_minutes?

  scope :due_for_fetch, -> { where("next_fetch_at <= ?", Time.current).where.not(next_fetch_at: nil) }

  def mark_as_fetched!(etag: nil, last_modified: nil)
    update!(
      status: :ok,
      error_message: nil,
      last_fetched_at: Time.current,
      next_fetch_at: fetch_interval_minutes.minutes.from_now,
      etag: etag || self.etag,
      last_modified: last_modified || self.last_modified
    )
  end

  def mark_as_error!(message)
    update!(
      status: :error,
      error_message: message,
      last_fetched_at: Time.current,
      next_fetch_at: ERROR_BACKOFF_MINUTES.minutes.from_now
    )
  end

  def conditional_get_headers
    headers = {}
    headers["If-None-Match"] = etag if etag.present?
    headers["If-Modified-Since"] = last_modified if last_modified.present?
    headers
  end

  def mark_all_entries_as_read!
    entries.unread.update_all(read_at: Time.current)
  end

  private

  def recalculate_next_fetch_at
    base = last_fetched_at || Time.current
    # Skip callbacks to avoid triggering after_save_commit again (would cause infinite loop)
    update_column(:next_fetch_at, base + fetch_interval_minutes.minutes)
  end

  def url_must_be_http
    uri = URI.parse(url)
    unless uri.is_a?(URI::HTTP) || uri.is_a?(URI::HTTPS)
      errors.add(:url, "must be an HTTP or HTTPS URL")
      return
    end

    # Block obvious private IP URLs at validation time.
    # Hostname-based SSRF (DNS rebinding etc.) is caught at fetch time by validate_url_safety!
    if url_changed?
      ip = IPAddr.new(uri.host)
      if Feed::Fetching::BLOCKED_IP_RANGES.any? { |range| range.include?(ip) }
        errors.add(:url, "cannot point to private network")
      end
    end
  rescue IPAddr::InvalidAddressError
    # Host is a hostname, not an IP literal — OK at validation time
  rescue URI::InvalidURIError
    errors.add(:url, "is not a valid URL")
  end
end
