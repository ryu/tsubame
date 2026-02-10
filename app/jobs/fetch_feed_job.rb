require "net/http"
require "rss"

class FetchFeedJob < ApplicationJob
  queue_as :default

  USER_AGENT = "Tsubame/1.0"
  OPEN_TIMEOUT = 10
  READ_TIMEOUT = 30
  MAX_REDIRECTS = 5
  MAX_RESPONSE_SIZE = 10.megabytes

  def perform(feed_id)
    feed = Feed.find_by(id: feed_id)
    return unless feed

    response = fetch_with_redirects(feed.url, feed.conditional_get_headers)

    if response.is_a?(Net::HTTPNotModified)
      feed.mark_as_fetched!
      return
    end

    unless response.is_a?(Net::HTTPSuccess)
      feed.mark_as_error!("HTTP error #{response.code}")
      Rails.logger.warn("FetchFeedJob: HTTP #{response.code} for feed #{feed_id}: #{response.message}")
      return
    end

    body = normalize_encoding(response)

    begin
      parsed = RSS::Parser.parse(body, false)
    rescue RSS::Error => e
      feed.mark_as_error!("Feed format error")
      Rails.logger.warn("FetchFeedJob: parse error for feed #{feed_id}: #{e.message}")
      return
    end

    unless parsed
      feed.mark_as_error!("Feed format error")
      return
    end

    import_entries(feed, parsed)

    feed.mark_as_fetched!(
      etag: response["ETag"],
      last_modified: response["Last-Modified"]
    )
  rescue Net::OpenTimeout, Net::ReadTimeout => e
    feed&.mark_as_error!("Request timed out")
    Rails.logger.error("FetchFeedJob timeout for feed #{feed_id}: #{e.class} - #{e.message}")
  rescue StandardError => e
    feed&.mark_as_error!("Failed to fetch feed") if feed
    Rails.logger.error("FetchFeedJob error for feed #{feed_id}: #{e.class} - #{e.message}")
  end

  private

  def fetch_with_redirects(url, headers, redirect_count = 0)
    raise "Too many redirects" if redirect_count >= MAX_REDIRECTS

    uri = URI.parse(url)
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

    # 304 Not Modified is technically a HTTPRedirection, but should not be followed
    if response.is_a?(Net::HTTPRedirection) && !response.is_a?(Net::HTTPNotModified)
      location = response["Location"]
      raise "Redirect without Location header" if location.blank?

      redirect_uri = URI.parse(location)
      redirect_url = redirect_uri.absolute? ? location : URI.join(url, location).to_s

      fetch_with_redirects(redirect_url, headers, redirect_count + 1)
    else
      response
    end
  end

  def validate_url_safety!(uri)
    raise "URL must use HTTP or HTTPS" unless uri.is_a?(URI::HTTP) || uri.is_a?(URI::HTTPS)
    raise "URL points to private network" if Feed.private_ip?(uri.host)
  end

  def enforce_response_size!(response)
    content_length = response["Content-Length"]&.to_i
    raise "Response too large" if content_length && content_length > MAX_RESPONSE_SIZE
    raise "Response too large" if response.body && response.body.bytesize > MAX_RESPONSE_SIZE
  end

  def import_entries(feed, parsed)
    update_feed_title(feed, parsed)

    items = extract_items(parsed)
    items.each do |item|
      guid = extract_guid(item)
      next if guid.blank?
      next if feed.entries.exists?(guid: guid)

      begin
        feed.entries.create!(
          guid: guid,
          title: extract_title(item),
          url: extract_url(item),
          author: extract_author(item),
          body: extract_body(item),
          published_at: extract_published_at(item)
        )
      rescue ActiveRecord::RecordInvalid => e
        Rails.logger.warn("FetchFeedJob: failed to create entry for feed #{feed.id}, guid #{guid}: #{e.message}")
      end
    end
  end

  def extract_items(parsed)
    # RSS::Parser.parse handles RSS 1.0, 2.0, and Atom
    parsed.items
  end

  def extract_guid(item)
    # RSS 2.0: item.guid.content, Atom: item.id.content
    if item.respond_to?(:guid) && item.guid
      item.guid.respond_to?(:content) ? item.guid.content : item.guid.to_s
    elsif item.respond_to?(:id) && item.id
      item.id.respond_to?(:content) ? item.id.content : item.id.to_s
    else
      item.link.to_s.presence
    end
  end

  def extract_title(item)
    title = if item.title.respond_to?(:content)
      item.title.content
    else
      item.title.to_s
    end
    strip_html(title)
  end

  def extract_url(item)
    return nil unless item.respond_to?(:link) && item.link

    if item.link.respond_to?(:href)
      item.link.href  # Atom
    elsif item.link.respond_to?(:first) && item.link.first.respond_to?(:href)
      # Atom with multiple links
      item.link.first.href
    else
      item.link.to_s  # RSS
    end
  end

  def extract_author(item)
    if item.respond_to?(:author) && item.author
      if item.author.respond_to?(:name) && item.author.name
        # Atom author.name is an object with .content method
        item.author.name.respond_to?(:content) ? item.author.name.content : item.author.name.to_s
      else
        item.author.to_s
      end
    elsif item.respond_to?(:dc_creator)
      item.dc_creator.to_s
    end
  end

  def extract_body(item)
    if item.respond_to?(:content) && item.content
      item.content.respond_to?(:content) ? item.content.content : item.content.to_s
    elsif item.respond_to?(:description) && item.description
      item.description.to_s
    elsif item.respond_to?(:summary) && item.summary
      item.summary.respond_to?(:content) ? item.summary.content : item.summary.to_s
    end
  end

  def extract_published_at(item)
    if item.respond_to?(:date) && item.date
      item.date
    elsif item.respond_to?(:pubDate) && item.pubDate
      item.pubDate
    elsif item.respond_to?(:updated) && item.updated
      # Atom updated is an object with .content method
      item.updated.respond_to?(:content) ? item.updated.content : item.updated
    end
  rescue StandardError
    nil
  end

  def normalize_encoding(response)
    body = response.body
    charset = response.type_params["charset"] rescue nil

    if charset.present?
      body.force_encoding(charset).encode("UTF-8", invalid: :replace, undef: :replace, replace: "")
    elsif body.encoding == Encoding::ASCII_8BIT
      utf8_body = body.dup.force_encoding("UTF-8")
      utf8_body.valid_encoding? ? utf8_body : body.encode("UTF-8", invalid: :replace, undef: :replace, replace: "")
    else
      body.encode("UTF-8", invalid: :replace, undef: :replace, replace: "")
    end
  end

  def update_feed_title(feed, parsed)
    title = if parsed.respond_to?(:channel) && parsed.channel&.title
      parsed.channel.title.to_s.presence
    elsif parsed.respond_to?(:title) && parsed.title
      t = parsed.title
      (t.respond_to?(:content) ? t.content : t.to_s).presence
    end
    feed.update_column(:title, title) if title.present?
  end

  def strip_html(html)
    return html unless html&.include?("<")
    html.gsub(%r{</?(div|p|br|li|h[1-6]|tr|td|th|dt|dd|section|article)[^>]*>}i, " ")
      .gsub(/<br\s*\/?>/, " ")
      .gsub(/<[^>]+>/, "")
      .squish
  end
end
