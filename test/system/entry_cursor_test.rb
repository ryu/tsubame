require "application_system_test_case"

class EntryCursorTest < ApplicationSystemTestCase
  # Selecting an entry while the list is still arriving used to lose the cursor:
  # the late turbo:frame-load reset it to -1 and every later shortcut (p, k, b)
  # went silently dead. Synthesize that trailing event to pin the behaviour down.
  test "a trailing entry_list frame load keeps the selected entry" do
    sign_in_as users(:one)

    click_on "Ruby Blog"
    within("#entry_list") { assert_text "Advanced Ruby Patterns" }

    find("body").send_keys("j")
    within("#entry_detail") { assert_text "Advanced Ruby Patterns" }
    assert_selector "#entry_list .entry-item[data-active='true']"

    page.execute_script(<<~JS)
      document.getElementById("entry_list")
        .dispatchEvent(new CustomEvent("turbo:frame-load", { bubbles: true }))
    JS

    assert_selector "#entry_list .entry-item[data-active='true']"

    # The cursor is still live, so pin toggling keeps working.
    find("body").send_keys("p")
    within("#entry_detail") { assert_selector ".pin-button", text: "ピン留め" }
  end

  # The flip side: when the entry really is gone from the reloaded list, the
  # cursor must drop rather than point at whatever now sits at that index.
  test "switching feeds clears the selected entry" do
    sign_in_as users(:one)

    click_on "Ruby Blog"
    within("#entry_list") { assert_text "Advanced Ruby Patterns" }
    find("body").send_keys("j")
    assert_selector "#entry_list .entry-item[data-active='true']"

    click_on "Rails News"
    within("#entry_list") { assert_text "Rails 8.1 Released" }
    assert_no_selector "#entry_list .entry-item[data-active='true']"
  end
end
