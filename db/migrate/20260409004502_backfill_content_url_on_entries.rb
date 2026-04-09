class BackfillContentUrlOnEntries < ActiveRecord::Migration[8.1]
  def up
    Entry.in_batches(of: 1000) do |batch|
      batch.each do |entry|
        normalized = Entry.normalize_url(entry.url)
        entry.update_column(:content_url, normalized) if normalized.present?
      end
    end
  end

  def down
    Entry.update_all(content_url: nil)
  end
end
