module Feed::EntryImporter
  extend ActiveSupport::Concern

  private

  def import_entries(parsed)
    update_feed_title(parsed)

    items = parsed.items.filter_map { |item| Entry.attributes_from_rss_item(item) }
    return if items.empty?

    existing_guids = entries.where(guid: items.map { |a| a[:guid] }).pluck(:guid).to_set

    items.each do |attrs|
      next if existing_guids.include?(attrs[:guid])

      entries.create!(attrs)
    rescue ActiveRecord::RecordInvalid => e
      Rails.logger.warn("Feed#fetch: failed to create entry for feed #{id}, guid #{attrs[:guid]}: #{e.message}")
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
