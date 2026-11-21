require "application_system_test_case"

class PinToggleTest < ApplicationSystemTestCase
  test "p unpins and repins the entry selected with the keyboard" do
    sign_in_as users(:one)

    click_on "Ruby Blog"
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
