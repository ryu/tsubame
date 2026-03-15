require "test_helper"

class FolderTest < ActiveSupport::TestCase
  test "should be valid with required attributes" do
    folder = Folder.new(name: "Technology", user: users(:one))
    assert folder.valid?
  end

  test "should require name presence" do
    folder = Folder.new(name: nil, user: users(:one))
    assert_not folder.valid?
    assert_includes folder.errors[:name], "を入力してください"
  end

  test "should require name to be present (empty string)" do
    folder = Folder.new(name: "", user: users(:one))
    assert_not folder.valid?
    assert_includes folder.errors[:name], "を入力してください"
  end

  test "should enforce unique folder name within same user" do
    existing = folders(:tech)
    folder = Folder.new(name: existing.name, user: existing.user)
    assert_not folder.valid?
    assert_includes folder.errors[:name], "はすでに存在します"
  end

  test "should allow same folder name for different users" do
    existing = folders(:tech)
    folder = Folder.new(name: existing.name, user: users(:two))
    assert folder.valid?
  end

  test "should allow different folder names" do
    folder = Folder.new(name: "Entertainment", user: users(:one))
    assert folder.valid?
  end

  test "should destroy folder and nullify associated subscriptions" do
    folder = folders(:tech)
    subscription_ids = folder.subscriptions.pluck(:id)

    assert_not subscription_ids.empty?, "Fixture should have subscriptions in tech folder"

    folder.destroy

    # Verify folder is deleted
    assert_not Folder.exists?(folder.id)

    # Verify subscriptions' folder_id is nil
    Subscription.where(id: subscription_ids).each do |subscription|
      assert_nil subscription.folder_id
    end
  end

  test "should reject name longer than 50 characters" do
    folder = Folder.new(name: "a" * 51, user: users(:one))
    assert_not folder.valid?
    assert folder.errors[:name].any?
  end

  test "should have many subscriptions" do
    folder = folders(:tech)
    assert_respond_to folder, :subscriptions
    assert_not folder.subscriptions.empty?
  end
end
