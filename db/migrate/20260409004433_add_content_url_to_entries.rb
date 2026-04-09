class AddContentUrlToEntries < ActiveRecord::Migration[8.1]
  def change
    add_column :entries, :content_url, :string
    add_index :entries, :content_url
  end
end
