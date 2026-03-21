require "test_helper"

class FolderGroupTest < ActiveSupport::TestCase
  test "name returns folder name when folder is present" do
    group = FolderGroup.new(folder: folders(:tech), subscriptions: [])
    assert_equal "Tech", group.name
  end

  test "name returns 未分類 when folder is nil" do
    group = FolderGroup.new(folder: nil, subscriptions: [])
    assert_equal "未分類", group.name
  end

  test "unread_count sums unread counts of subscriptions" do
    subscriptions = [
      Struct.new(:unread_count).new(2),
      Struct.new(:unread_count).new(5),
      Struct.new(:unread_count).new(0)
    ]

    group = FolderGroup.new(folder: folders(:tech), subscriptions: subscriptions)

    assert_equal 7, group.unread_count
  end
end
