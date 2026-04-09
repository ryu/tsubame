class Entry < ApplicationRecord
  include Entry::RssParser

  belongs_to :feed
  has_many :user_entry_states, dependent: :destroy

  validates :guid, presence: true, uniqueness: { scope: :feed_id }

  before_save :set_content_url, if: :url_changed?

  scope :recently_published, -> { order(published_at: :desc) }
  scope :duplicates_of, ->(entry) {
    return none if entry.content_url.blank?
    where(content_url: entry.content_url).where.not(id: entry.id)
  }

  def self.normalize_url(raw_url)
    return nil if raw_url.blank?

    uri = URI.parse(raw_url)
    return nil unless uri.is_a?(URI::HTTP) || uri.is_a?(URI::HTTPS)

    if uri.query.present?
      cleaned_params = URI.decode_www_form(uri.query).reject do |key, _|
        key.match?(/\Autm_/i) || %w[fbclid gclid].include?(key.downcase)
      end
      uri.query = cleaned_params.empty? ? nil : URI.encode_www_form(cleaned_params)
    end

    uri.fragment = nil
    uri.path = uri.path.chomp("/") if uri.path.length > 1

    uri.to_s
  rescue URI::InvalidURIError
    nil
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

  private

  def set_content_url
    self.content_url = self.class.normalize_url(url)
  end
end
