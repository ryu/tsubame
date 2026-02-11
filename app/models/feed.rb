require "cgi"
require "net/http"
require "rexml/document"
require "resolv"
require "rss"
require "ipaddr"

class Feed < ApplicationRecord
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
            raw_title = outline.attributes["title"] || outline.attributes["text"]
          create!(
              url: normalized_url,
              title: raw_title ? CGI.unescapeHTML(raw_title) : nil,
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

  USER_AGENT = "Tsubame/1.0"
  OPEN_TIMEOUT = 10
  READ_TIMEOUT = 30
  MAX_REDIRECTS = 5
  MAX_RESPONSE_SIZE = 10.megabytes

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

  def fetch
    response = fetch_with_redirects(url, conditional_get_headers)

    if response.is_a?(Net::HTTPNotModified)
      mark_as_fetched!
      return
    end

    unless response.is_a?(Net::HTTPSuccess)
      mark_as_error!("HTTP error #{response.code}")
      Rails.logger.warn("Feed#fetch: HTTP #{response.code} for feed #{id}: #{response.message}")
      return
    end

    body = normalize_encoding(response)
    parsed = parse_feed(body)
    return unless parsed

    import_entries(parsed)

    mark_as_fetched!(
      etag: response["ETag"],
      last_modified: response["Last-Modified"]
    )
  rescue Net::OpenTimeout, Net::ReadTimeout => e
    mark_as_error!("Request timed out")
    Rails.logger.error("Feed#fetch timeout for feed #{id}: #{e.class} - #{e.message}")
  rescue StandardError => e
    mark_as_error!("Failed to fetch feed")
    Rails.logger.error("Feed#fetch error for feed #{id}: #{e.class} - #{e.message}")
  end

  private

  def fetch_with_redirects(target_url, headers, redirect_count = 0)
    raise "Too many redirects" if redirect_count >= MAX_REDIRECTS

    uri = URI.parse(target_url)
    validate_url_safety!(uri)

    http = Net::HTTP.new(uri.host, uri.port)
    http.use_ssl = (uri.scheme == "https")
    http.open_timeout = OPEN_TIMEOUT
    http.read_timeout = READ_TIMEOUT

    request = Net::HTTP::Get.new(uri)
    request["User-Agent"] = USER_AGENT
    headers.each { |key, value| request[key] = value }

    response = http.request(request)
    enforce_response_size!(response)

    if response.is_a?(Net::HTTPRedirection) && !response.is_a?(Net::HTTPNotModified)
      location = response["Location"]
      raise "Redirect without Location header" if location.blank?

      redirect_uri = URI.parse(location)
      redirect_url = redirect_uri.absolute? ? location : URI.join(target_url, location).to_s

      fetch_with_redirects(redirect_url, headers, redirect_count + 1)
    else
      response
    end
  end

  def validate_url_safety!(uri)
    raise "URL must use HTTP or HTTPS" unless uri.is_a?(URI::HTTP) || uri.is_a?(URI::HTTPS)
    raise "URL points to private network" if self.class.private_ip?(uri.host)
  end

  def enforce_response_size!(response)
    content_length = response["Content-Length"]&.to_i
    raise "Response too large" if content_length && content_length > MAX_RESPONSE_SIZE
    raise "Response too large" if response.body && response.body.bytesize > MAX_RESPONSE_SIZE
  end

  def normalize_encoding(response)
    body = response.body.dup
    charset = begin
      response.type_params["charset"]
    rescue NoMethodError, TypeError
      nil
    end
    charset ||= detect_xml_encoding(body)

    if charset.present?
      encoded = body.force_encoding(charset).encode("UTF-8", invalid: :replace, undef: :replace)
      encoded.sub!(/(<\?xml[^?]*encoding=)["'][^"']+["']/i, '\1"UTF-8"')
      encoded
    elsif body.encoding == Encoding::ASCII_8BIT
      utf8_body = body.dup.force_encoding("UTF-8")
      utf8_body.valid_encoding? ? utf8_body : body.encode("UTF-8", invalid: :replace, undef: :replace)
    else
      body.encode("UTF-8", invalid: :replace, undef: :replace)
    end
  end

  def detect_xml_encoding(body)
    header = body.byteslice(0, 200)
    return unless header

    ascii_header = header.dup.force_encoding("ASCII-8BIT")
    if ascii_header.match?(/\A\s*<\?xml/i)
      match = ascii_header.match(/encoding=["']([^"']+)["']/i)
      match[1] if match
    end
  end

  def parse_feed(body)
    parsed = RSS::Parser.parse(body, false)
    unless parsed
      mark_as_error!("Feed format error")
      return nil
    end
    parsed
  rescue RSS::Error => e
    mark_as_error!("Feed format error")
    Rails.logger.warn("Feed#fetch: parse error for feed #{id}: #{e.message}")
    nil
  end

  def import_entries(parsed)
    update_feed_title(parsed)

    parsed.items.each do |item|
      attrs = Entry.attributes_from_rss_item(item)
      next unless attrs
      next if entries.exists?(guid: attrs[:guid])

      begin
        entries.create!(attrs)
      rescue ActiveRecord::RecordInvalid => e
        Rails.logger.warn("Feed#fetch: failed to create entry for feed #{id}, guid #{attrs[:guid]}: #{e.message}")
      end
    end
  end

  def update_feed_title(parsed)
    title = if parsed.respond_to?(:channel) && parsed.channel&.title
      parsed.channel.title.to_s.presence
    elsif parsed.respond_to?(:title) && parsed.title
      t = parsed.title
      (t.respond_to?(:content) ? t.content : t.to_s).presence
    end
    # Skip callbacks/validations — just persisting the parsed title, no need to touch updated_at
    update_column(:title, title) if title.present?
  end

  def recalculate_next_fetch_at
    base = last_fetched_at || Time.current
    # Skip callbacks to avoid triggering after_save_commit again (would cause infinite loop)
    update_column(:next_fetch_at, base + fetch_interval_minutes.minutes)
  end

  def url_must_be_http
    uri = URI.parse(url)
    unless uri.is_a?(URI::HTTP) || uri.is_a?(URI::HTTPS)
      errors.add(:url, "must be an HTTP or HTTPS URL")
    end
  rescue URI::InvalidURIError
    errors.add(:url, "is not a valid URL")
  end
end
