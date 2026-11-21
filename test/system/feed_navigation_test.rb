require "application_system_test_case"

class FeedNavigationTest < ApplicationSystemTestCase
  test "signs in, opens a feed, and selects an entry with the keyboard" do
    sign_in_as users(:one)

    assert_selector ".feed-item", text: "Ruby Blog"

    click_on "Ruby Blog"
    within "#entry_list" do
      assert_text "Advanced Ruby Patterns"
    end

    find("body").send_keys("j")
    within "#entry_detail" do
      assert_text "Advanced Ruby Patterns"
    end
  end

  test "entry selection resets when switching feeds" do
    sign_in_as users(:one)

    click_on "Ruby Blog"
    within "#entry_list" do
      assert_text "Advanced Ruby Patterns"
    end

    find("body").send_keys("j")
    within "#entry_detail" do
      assert_text "Advanced Ruby Patterns"
    end

    click_on "Rails News"
    within "#entry_list" do
      assert_text "Rails 8.1 Released"
    end

    find("body").send_keys("j")
    within "#entry_detail" do
      assert_text "Rails 8.1 Released"
    end
  end
end
