require "test_helper"

class UserTest < ActiveSupport::TestCase
  test "downcases and strips email_address" do
    user = User.new(email_address: " DOWNCASED@EXAMPLE.COM ")
    assert_equal("downcased@example.com", user.email_address)
  end

  test "grouped_subscriptions_for_home returns folder groups with unread counts" do
    groups = users(:one).grouped_subscriptions_for_home(rate: 0)

    assert_kind_of FolderGroup, groups.first

    tech_group = groups.find { |group| group.folder == folders(:tech) }
    assert_not_nil tech_group
    assert_equal 2, tech_group.unread_count
    assert_equal [ subscriptions(:user_one_rails_news), subscriptions(:user_one_ruby_blog) ],
      tech_group.subscriptions
  end
end
