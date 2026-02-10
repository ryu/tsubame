require "rexml/document"
require "resolv"
require "ipaddr"

class Feed < ApplicationRecord
  has_many :entries, dependent: :destroy

  enum :status, { ok: 0, error: 1 }, default: :ok

  validates :url, presence: true, uniqueness: true
  validate :url_must_be_http, if: -> { url.present? }

  normalizes :url, with: ->(url) { url.strip.gsub(/&(amp;)+/, "&") }

  FETCH_INTERVAL = 10.minutes
  ERROR_FETCH_INTERVAL = 30.minutes

  scope :due_for_fetch, -> { where("next_fetch_at <= ?", Time.current).where.not(next_fetch_at: nil) }

  def mark_as_fetched!(etag: nil, last_modified: nil)
    update!(
      status: :ok,
      error_message: nil,
      last_fetched_at: Time.current,
      next_fetch_at: FETCH_INTERVAL.from_now,
      etag: etag || self.etag,
      last_modified: last_modified || self.last_modified
    )
  end

  def mark_as_error!(message)
    update!(
      status: :error,
      error_message: message,
      last_fetched_at: Time.current,
      next_fetch_at: ERROR_FETCH_INTERVAL.from_now
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

  # Import feeds from OPML XML content
  # Returns { added: N, skipped: N }
  def self.import_from_opml(xml_content)
    doc = REXML::Document.new(xml_content, entity_expansion_text_limit: 0)
    added = 0
    skipped = 0
    existing_urls = pluck(:url).to_set

    process_outline = ->(element) do
      element.each_element("outline") do |outline|
        xml_url = outline.attributes["xmlUrl"]

        if xml_url.present?
          normalized_url = xml_url.strip
          unless existing_urls.include?(normalized_url)
            create!(
              url: normalized_url,
              title: outline.attributes["title"] || outline.attributes["text"],
              site_url: outline.attributes["htmlUrl"],
              status: :ok,
              next_fetch_at: Time.current
            )
            existing_urls << normalized_url
            added += 1
          else
            skipped += 1
          end
        else
          process_outline.call(outline)
        end
      end
    end

    doc.each_element("//body") do |body|
      process_outline.call(body)
    end

    { added: added, skipped: skipped }
  rescue REXML::ParseException
    raise "OPMLファイルの形式が正しくありません。"
  end

  # Export feeds to OPML 1.0 XML format
  # Returns XML string
  def self.to_opml
    doc = REXML::Document.new
    doc << REXML::XMLDecl.new("1.0", "UTF-8")

    opml = doc.add_element("opml", { "version" => "1.0" })
    head = opml.add_element("head")
    head.add_element("title").add_text("Tsubame Subscriptions")

    body = opml.add_element("body")

    all.order(:title).each do |feed|
      attrs = {
        "type" => "rss",
        "text" => feed.title || feed.url,
        "title" => feed.title || feed.url,
        "xmlUrl" => feed.url
      }
      attrs["htmlUrl"] = feed.site_url if feed.site_url.present?
      body.add_element("outline", attrs)
    end

    output = ""
    doc.write(output)
    output
  end

  BLOCKED_IP_RANGES = [
    IPAddr.new("127.0.0.0/8"),
    IPAddr.new("10.0.0.0/8"),
    IPAddr.new("172.16.0.0/12"),
    IPAddr.new("192.168.0.0/16"),
    IPAddr.new("169.254.0.0/16"),
    IPAddr.new("::1/128"),
    IPAddr.new("fc00::/7")
  ].freeze

  def self.private_ip?(host)
    ip = Resolv.getaddress(host)
    ip_addr = IPAddr.new(ip)
    BLOCKED_IP_RANGES.any? { |range| range.include?(ip_addr) }
  rescue Resolv::ResolvError, SocketError, IPAddr::InvalidAddressError
    true
  end

  private

  def url_must_be_http
    uri = URI.parse(url)
    unless uri.is_a?(URI::HTTP) || uri.is_a?(URI::HTTPS)
      errors.add(:url, "must be an HTTP or HTTPS URL")
    end
  rescue URI::InvalidURIError
    errors.add(:url, "is not a valid URL")
  end
end
