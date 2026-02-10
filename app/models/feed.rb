require "rexml/document"

class Feed < ApplicationRecord
  has_many :entries, dependent: :destroy

  enum :status, { ok: 0, error: 1 }, default: :ok

  validates :url, presence: true, uniqueness: true

  normalizes :url, with: ->(url) { url.strip }

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
end
