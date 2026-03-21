class FolderGroup
  attr_reader :folder, :subscriptions

  def initialize(folder:, subscriptions:)
    @folder = folder
    @subscriptions = subscriptions
  end

  def name
    folder&.name || "未分類"
  end

  def unread_count
    subscriptions.sum(&:unread_count)
  end
end
