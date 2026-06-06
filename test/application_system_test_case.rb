require "test_helper"

class ApplicationSystemTestCase < ActionDispatch::SystemTestCase
  driven_by :selenium, using: :headless_chrome, screen_size: [ 1400, 1400 ]

  private

  # Log in through the real magic-link flow (this app has no password auth).
  def sign_in_as(user)
    visit magic_link_path(MagicLink.generate_for(user))
  end
end
