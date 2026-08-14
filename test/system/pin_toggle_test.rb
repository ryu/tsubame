require "application_system_test_case"

class PinToggleTest < ApplicationSystemTestCase
  # `p` reaches the active entry through the pin controller's entry-list outlet.
  # A mis-wired outlet fails silently, so exercise it end to end.
  test "p unpins and repins the entry selected with the keyboard" do
    sign_in_as users(:one)

    click_on "Ruby Blog"
    # Wait for the entry_list frame to settle: its turbo:frame-load resets the
    # entry cursor, so pressing `j` before it lands would wipe the selection.
    within("#entry_list") { assert_text "Advanced Ruby Patterns" }

    find("body").send_keys("j")
    within "#entry_detail" do
      assert_text "Advanced Ruby Patterns"
      assert_selector ".pin-button", text: "ピン解除"
    end
    within("#entry_list") { assert_selector ".entry-item .pin-icon" }

    find("body").send_keys("p")
    within("#entry_detail") { assert_selector ".pin-button", text: "ピン留め" }
    within("#entry_list") { assert_no_selector ".entry-item .pin-icon" }

    find("body").send_keys("p")
    within("#entry_detail") { assert_selector ".pin-button", text: "ピン解除" }
    within("#entry_list") { assert_selector ".entry-item .pin-icon" }
  end
end
