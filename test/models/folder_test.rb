require "test_helper"

class FolderTest < ActiveSupport::TestCase
  test "should be valid with required attributes" do
    folder = Folder.new(name: "Technology")
    assert folder.valid?
  end

  test "should require name presence" do
    folder = Folder.new(name: nil)
    assert_not folder.valid?
    assert_includes folder.errors[:name], "を入力してください"
  end

  test "should require name to be present (empty string)" do
    folder = Folder.new(name: "")
    assert_not folder.valid?
    assert_includes folder.errors[:name], "を入力してください"
  end

  test "should enforce unique folder name" do
    existing = folders(:tech)
    folder = Folder.new(name: existing.name)
    assert_not folder.valid?
    assert_includes folder.errors[:name], "はすでに存在します"
  end

  test "should allow different folder names" do
    folder = Folder.new(name: "Entertainment")
    assert folder.valid?
  end

  test "should destroy folder and nullify associated feeds" do
    folder = folders(:tech)
    feed_ids = folder.feeds.pluck(:id)

    assert_not feed_ids.empty?, "Fixture should have feeds in tech folder"

    folder.destroy

    # Verify folder is deleted
    assert_not Folder.exists?(folder.id)

    # Verify feeds' folder_id is nil
    Feed.where(id: feed_ids).each do |feed|
      assert_nil feed.folder_id
    end
  end

  test "should reject name longer than 50 characters" do
    folder = Folder.new(name: "a" * 51)
    assert_not folder.valid?
    assert folder.errors[:name].any?
  end

  test "should have many feeds" do
    folder = folders(:tech)
    assert_respond_to folder, :feeds
    assert_not folder.feeds.empty?
  end
end
