require "application_system_test_case"

class FeedNavigationTest < ApplicationSystemTestCase
  test "signs in, opens a feed, and selects an entry with the keyboard" do
    sign_in_as users(:one)

    # The home screen lists the user's subscribed feeds.
    assert_selector ".feed-item", text: "Ruby Blog"

    # Selecting a feed loads its unread entries into the Turbo frame.
    # (Per fixtures, only "Advanced Ruby Patterns" is unread for this user.)
    click_on "Ruby Blog"
    within "#entry_list" do
      assert_text "Advanced Ruby Patterns"
    end

    # `j` routes through the keyboard + selection Stimulus controllers to select
    # the first entry and load its detail via Turbo.
    find("body").send_keys("j")
    within "#entry_detail" do
      assert_text "Advanced Ruby Patterns"
    end
  end
end
