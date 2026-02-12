require "net/http"
require "resolv"
require "rss"
require "ipaddr"

module Feed::Fetching
  extend ActiveSupport::Concern

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

  class_methods do
    def private_ip?(host)
      ip = Resolv.getaddress(host)
      ip_addr = IPAddr.new(ip)
      BLOCKED_IP_RANGES.any? { |range| range.include?(ip_addr) }
    rescue Resolv::ResolvError, SocketError, IPAddr::InvalidAddressError
      true
    end
  end

  def fetch
    response = fetch_with_redirects(url, conditional_get_headers)

    if response.is_a?(Net::HTTPNotModified)
      record_successful_fetch!
      return
    end

    unless response.is_a?(Net::HTTPSuccess)
      record_fetch_error!("HTTP error #{response.code}")
      Rails.logger.warn("Feed#fetch: HTTP #{response.code} for feed #{id}: #{response.message}")
      return
    end

    body = normalize_encoding(response)
    parsed = parse_feed(body)
    return unless parsed

    import_entries(parsed)

    record_successful_fetch!(
      new_etag: response["ETag"],
      new_last_modified: response["Last-Modified"]
    )
  rescue Net::OpenTimeout, Net::ReadTimeout => e
    record_fetch_error!("Request timed out")
    Rails.logger.error("Feed#fetch timeout for feed #{id}: #{e.class} - #{e.message}")
  rescue StandardError => e
    record_fetch_error!("Failed to fetch feed")
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
      record_fetch_error!("Feed format error")
      return nil
    end
    parsed
  rescue RSS::Error => e
    record_fetch_error!("Feed format error")
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
end
