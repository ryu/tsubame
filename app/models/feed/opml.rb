require "cgi"
require "rexml/document"

module Feed::Opml
  extend ActiveSupport::Concern

  class_methods do
    # Import feeds from OPML XML content
    # Returns { added: N, skipped: N }
    def import_from_opml(xml_content)
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
    def to_opml
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
  end
end
