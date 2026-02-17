class Feed < ApplicationRecord
  include Feed::Fetching       # HTTP通信・SSRF保護・エンコーディング・パース（BLOCKED_IP_RANGESを定義）
  include Feed::EntryImporter  # エントリインポート・フィードタイトル更新
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

  # record_successful_fetch! / record_fetch_error! set next_fetch_at explicitly;
  # this callback only fires when fetch_interval_minutes is changed (e.g. from settings).
  before_save :set_next_fetch_at, if: :fetch_interval_minutes_changed?

  scope :due_for_fetch, -> { where("next_fetch_at <= ?", Time.current).where.not(next_fetch_at: nil) }

  scope :with_unread_count, -> {
    left_joins(:entries)
      .select("feeds.*, COUNT(CASE WHEN entries.id IS NOT NULL AND entries.read_at IS NULL THEN 1 END) as unread_count")
      .group("feeds.id")
  }

  # Only feeds that have at least one unread entry
  # SQLite does not support column aliases in HAVING, so we repeat the full expression
  scope :with_unreads, -> {
    with_unread_count
      .having("COUNT(CASE WHEN entries.id IS NOT NULL AND entries.read_at IS NULL THEN 1 END) > 0")
  }

  # Virtual attribute populated by with_unread_count / with_unreads scope
  def unread_count
    self[:unread_count] || 0
  end

  def record_successful_fetch!(new_etag: nil, new_last_modified: nil)
    update!(
      status: :ok,
      error_message: nil,
      last_fetched_at: Time.current,
      next_fetch_at: fetch_interval_minutes.minutes.from_now,
      etag: new_etag || etag,
      last_modified: new_last_modified || last_modified
    )
  end

  def record_fetch_error!(message)
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

  def set_next_fetch_at
    base = last_fetched_at || Time.current
    self.next_fetch_at = base + fetch_interval_minutes.minutes
  end

  def url_must_be_http
    uri = URI.parse(url)
    unless uri.is_a?(URI::HTTP) || uri.is_a?(URI::HTTPS)
      errors.add(:url, "must be an HTTP or HTTPS URL")
      return
    end

    # Block IP literal URLs pointing to private networks at validation time.
    # Hostname-based SSRF (DNS rebinding etc.) is caught at fetch time by validate_url_safety!
    if url_changed? && ip_literal?(uri.host)
      ip = IPAddr.new(uri.host)
      if Feed::Fetching::BLOCKED_IP_RANGES.any? { |range| range.include?(ip) }
        errors.add(:url, "cannot point to private network")
      end
    end
  rescue URI::InvalidURIError
    errors.add(:url, "is not a valid URL")
  end

  def ip_literal?(host)
    IPAddr.new(host)
    true
  rescue IPAddr::InvalidAddressError
    false
  end
end
