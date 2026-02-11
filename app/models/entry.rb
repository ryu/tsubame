class Entry < ApplicationRecord
  belongs_to :feed

  validates :guid, presence: true, uniqueness: { scope: :feed_id }

  scope :unread, -> { where(read_at: nil) }
  scope :pinned, -> { where(pinned: true) }
  scope :recent, -> { order(published_at: :desc) }

  # Build an attributes Hash from an RSS/Atom/RDF item.
  # Returns nil if the item has no usable guid.
  def self.attributes_from_rss_item(item)
    guid = extract_guid(item)
    return nil if guid.blank?

    {
      guid: guid,
      title: extract_title(item),
      url: extract_url(item),
      author: extract_author(item),
      body: extract_body(item),
      published_at: extract_published_at(item)
    }
  end

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

  # Returns sanitized URL for safe use in links
  # Returns nil if URL is invalid
  def safe_url
    return nil if url.blank?

    uri = URI.parse(url)
    return nil unless uri.is_a?(URI::HTTP) || uri.is_a?(URI::HTTPS)

    url
  rescue URI::InvalidURIError
    nil
  end

  # -- Private class methods for RSS item extraction --

  def self.extract_guid(item)
    if item.respond_to?(:guid) && item.guid
      item.guid.respond_to?(:content) ? item.guid.content : item.guid.to_s
    elsif item.respond_to?(:id) && item.id
      item.id.respond_to?(:content) ? item.id.content : item.id.to_s
    else
      item.link.to_s.presence
    end
  end
  private_class_method :extract_guid

  def self.extract_title(item)
    title = if item.title.respond_to?(:content)
      item.title.content
    else
      item.title.to_s
    end
    strip_html(title)
  end
  private_class_method :extract_title

  def self.extract_url(item)
    return nil unless item.respond_to?(:link) && item.link

    if item.link.respond_to?(:href)
      item.link.href
    elsif item.link.respond_to?(:first) && item.link.first.respond_to?(:href)
      item.link.first.href
    else
      item.link.to_s
    end
  end
  private_class_method :extract_url

  def self.extract_author(item)
    if item.respond_to?(:author) && item.author
      if item.author.respond_to?(:name) && item.author.name
        item.author.name.respond_to?(:content) ? item.author.name.content : item.author.name.to_s
      else
        item.author.to_s
      end
    elsif item.respond_to?(:dc_creator)
      item.dc_creator.to_s
    end
  end
  private_class_method :extract_author

  def self.extract_body(item)
    if item.respond_to?(:content_encoded) && item.content_encoded
      item.content_encoded
    elsif item.respond_to?(:content) && item.content
      item.content.respond_to?(:content) ? item.content.content : item.content.to_s
    elsif item.respond_to?(:description) && item.description
      item.description.to_s
    elsif item.respond_to?(:summary) && item.summary
      item.summary.respond_to?(:content) ? item.summary.content : item.summary.to_s
    end
  end
  private_class_method :extract_body

  def self.extract_published_at(item)
    if item.respond_to?(:date) && item.date
      item.date
    elsif item.respond_to?(:pubDate) && item.pubDate
      item.pubDate
    elsif item.respond_to?(:updated) && item.updated
      item.updated.respond_to?(:content) ? item.updated.content : item.updated
    end
  rescue StandardError
    nil
  end
  private_class_method :extract_published_at

  def self.strip_html(html)
    return html unless html&.include?("<")
    html.gsub(%r{</?(div|p|br|li|h[1-6]|tr|td|th|dt|dd|section|article)[^>]*>}i, " ")
      .gsub(/<br\s*\/?>/, " ")
      .gsub(/<[^>]+>/, "")
      .squish
  end
  private_class_method :strip_html
end
