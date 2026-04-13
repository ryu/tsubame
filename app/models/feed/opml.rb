require "cgi"
require "rexml/document"

module Feed::Opml
  class ImportError < StandardError; end

  extend ActiveSupport::Concern

  class_methods do
    # Import feeds from OPML XML content for a specific user
    # Returns { added: N, skipped: N }
    def import_from_opml(xml_content, user:)
      doc = REXML::Document.new(xml_content, entity_expansion_text_limit: 0)
      existing_feed_urls = user.subscriptions.joins(:feed).pluck("feeds.url").to_set
      state = { added: 0, skipped: 0, existing_urls: existing_feed_urls, user: user }

      doc.each_element("//body") do |body|
        import_outlines(body, state)
      end

      { added: state[:added], skipped: state[:skipped] }
    rescue REXML::ParseException
      raise ImportError, "OPMLファイルの形式が正しくありません。"
    end

    # Export subscribed feeds to OPML 1.0 XML format for a specific user
    # Returns XML string
    def to_opml(user:)
      doc = REXML::Document.new
      doc << REXML::XMLDecl.new("1.0", "UTF-8")

      opml = doc.add_element("opml", { "version" => "1.0" })
      head = opml.add_element("head")
      head.add_element("title").add_text("Tsubame Subscriptions")

      body = opml.add_element("body")

      user.subscriptions.includes(:feed).joins(:feed).merge(Feed.order(:title)).each do |sub|
        feed = sub.feed
        attrs = {
          "type" => "rss",
          "text" => sub.display_title,
          "title" => sub.display_title,
          "xmlUrl" => feed.url
        }
        attrs["htmlUrl"] = feed.site_url if feed.site_url.present?
        body.add_element("outline", attrs)
      end

      output = String.new
      doc.write(output)
      output
    end

    private

    def import_outlines(element, state)
      element.each_element("outline") do |outline|
        if outline.attributes["xmlUrl"].present?
          import_feed_from_outline(outline, state)
        else
          import_outlines(outline, state)
        end
      end
    end

    def import_feed_from_outline(outline, state)
      url = outline.attributes["xmlUrl"].strip

      if state[:existing_urls].include?(url)
        state[:skipped] += 1
        return
      end

      raw_title = outline.attributes["title"] || outline.attributes["text"]
      feed = Feed.find_or_create_by!(url: url) do |f|
        f.title = raw_title ? CGI.unescapeHTML(raw_title) : nil
        f.site_url = outline.attributes["htmlUrl"]
        f.status = :ok
        f.next_fetch_at = Time.current
      end
      state[:user].subscribe_to(feed)
      state[:existing_urls] << url
      state[:added] += 1
    rescue ActiveRecord::RecordInvalid, ActiveRecord::RecordNotUnique => e
      Rails.logger.warn("OPML import: skipped invalid feed #{url}: #{e.message}")
      state[:skipped] += 1
    end
  end
end
