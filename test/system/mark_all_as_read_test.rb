require "application_system_test_case"

class MarkAllAsReadTest < ApplicationSystemTestCase
  test "Shift+A marks the current feed as read via a morph refresh" do
    sign_in_as users(:one)

    click_on "Ruby Blog"
    within "#entry_list" do
      assert_selector ".entry-item.entry-unread", text: "Advanced Ruby Patterns"
    end

    find("body").send_keys([ :shift, "a" ])

    within "#entry_list" do
      assert_text "エントリがありません"
      assert_no_text "左からフィードを選択してください"
    end

    assert_no_selector ".feed-item", text: "Ruby Blog"
    find(".feed-item", text: "Rails News").assert_selector(".unread-badge", text: "1")
  end

  test "Shift+A preserves the open entry detail across the refresh" do
    sign_in_as users(:one)

    click_on "Ruby Blog"
    within "#entry_list" do
      assert_text "Advanced Ruby Patterns"
    end

    find("body").send_keys("j")
    within "#entry_detail" do
      assert_text "Advanced Ruby Patterns"
    end

    find("body").send_keys([ :shift, "a" ])

    within "#entry_list" do
      assert_text "エントリがありません"
    end
    within "#entry_detail" do
      assert_text "Advanced Ruby Patterns"
      assert_no_text "エントリを選択してください"
    end
  end
end
