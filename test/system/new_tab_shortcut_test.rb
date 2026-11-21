require "application_system_test_case"

class NewTabShortcutTest < ApplicationSystemTestCase
  test "v opens the selected entry's original article in a new tab" do
    sign_in_as users(:one)

    click_on "Ruby Blog"
    within("#entry_list") { assert_text "Advanced Ruby Patterns" }
    find("body").send_keys("j")
    within("#entry_detail") { assert_text "Advanced Ruby Patterns" }

    new_tab = window_opened_by { find("body").send_keys("v") }

    assert_equal entries(:ruby_article_two).url, new_tab.session.within_window(new_tab) { current_url }
  ensure
    new_tab&.close
  end

  test "o opens every pinned entry in a new tab" do
    sign_in_as users(:one)
    assert_selector "#pin_badge"

    new_tab = window_opened_by { find("body").send_keys("o") }

    assert new_tab.exists?
  ensure
    new_tab&.close
  end
end
