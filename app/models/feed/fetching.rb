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

  # Number of bytes to probe for XML encoding declaration
  XML_ENCODING_PROBE_SIZE = 200

  BLOCKED_IP_RANGES = [
    IPAddr.new("0.0.0.0/8"),
    IPAddr.new("127.0.0.0/8"),
    IPAddr.new("10.0.0.0/8"),
    IPAddr.new("172.16.0.0/12"),
    IPAddr.new("192.168.0.0/16"),
    IPAddr.new("169.254.0.0/16"),
    IPAddr.new("::1/128"),
    IPAddr.new("fc00::/7"),
    IPAddr.new("fe80::/10")
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
    response, body = fetch_with_redirects(url, conditional_get_headers)

    if response.is_a?(Net::HTTPNotModified)
      record_successful_fetch!
      return
    end

    unless response.is_a?(Net::HTTPSuccess)
      record_fetch_error!("HTTP error #{response.code}")
      Rails.logger.warn("Feed#fetch: HTTP #{response.code} for feed #{id}: #{response.message}")
      return
    end

    body = normalize_encoding(response, body)
    parsed = parse_feed(body)
    unless parsed
      record_fetch_error!("Feed format error")
      return
    end

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

  def fetch_with_redirects(target_url, headers)
    current_url = target_url
    redirect_count = 0

    loop do
      raise "Too many redirects" if redirect_count >= MAX_REDIRECTS

      uri = URI.parse(current_url)
      resolved_ip = validate_url_safety!(uri)
      response, body = perform_request(uri, resolved_ip, headers)

      if response.is_a?(Net::HTTPRedirection) && !response.is_a?(Net::HTTPNotModified)
        location = response["Location"]
        raise "Redirect without Location header" if location.blank?

        redirect_uri = URI.parse(location)
        current_url = redirect_uri.absolute? ? location : URI.join(current_url, location).to_s
        redirect_count += 1
      else
        return [ response, body ]
      end
    end
  end

  def perform_request(uri, resolved_ip, headers)
    http = Net::HTTP.new(uri.host, uri.port)
    http.ipaddr = resolved_ip
    http.use_ssl = (uri.scheme == "https")
    http.open_timeout = OPEN_TIMEOUT
    http.read_timeout = READ_TIMEOUT

    request = Net::HTTP::Get.new(uri)
    request["User-Agent"] = USER_AGENT
    headers.each { |key, value| request[key] = value }

    result_response = nil
    result_body = nil

    http.request(request) do |response|
      # Reject early based on Content-Length before reading the body
      content_length = response["Content-Length"]&.to_i
      raise "Response too large" if content_length && content_length > MAX_RESPONSE_SIZE

      # Stream-read body with size limit only for success responses
      if response.is_a?(Net::HTTPSuccess)
        result_body = read_body_with_limit!(response)
      end

      result_response = response
    end

    [ result_response, result_body ]
  end

  def read_body_with_limit!(response)
    body = +""
    response.read_body do |chunk|
      body << chunk
      raise "Response too large" if body.bytesize > MAX_RESPONSE_SIZE
    end
    body
  end

  def validate_url_safety!(uri)
    raise "URL must use HTTP or HTTPS" unless uri.is_a?(URI::HTTP) || uri.is_a?(URI::HTTPS)

    ip = Resolv.getaddress(uri.host)
    ip_addr = IPAddr.new(ip)
    raise "URL points to private network" if BLOCKED_IP_RANGES.any? { |range| range.include?(ip_addr) }

    ip
  rescue Resolv::ResolvError, SocketError, IPAddr::InvalidAddressError
    raise "Cannot resolve hostname"
  end

  def normalize_encoding(response, body)
    body = body.dup
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
    header = body.byteslice(0, XML_ENCODING_PROBE_SIZE)
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
      Rails.logger.warn("Feed#fetch: empty parse result for feed #{id}")
      return nil
    end
    parsed
  rescue RSS::Error => e
    Rails.logger.warn("Feed#fetch: parse error for feed #{id}: #{e.message}")
    nil
  end
end
