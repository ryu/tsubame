require "test_helper"

class ApplicationSystemTestCase < ActionDispatch::SystemTestCase
  driven_by :selenium, using: :headless_chrome, screen_size: [ 1400, 1400 ]

  # Forgery protection is off in the test environment, which leaves csrf_meta_tags
  # empty and breaks fetchWithCsrf. Turn it on so system tests exercise the real flow.
  setup { ActionController::Base.allow_forgery_protection = true }
  teardown { ActionController::Base.allow_forgery_protection = false }

  private

  # Log in through the real magic-link flow (this app has no password auth).
  def sign_in_as(user)
    visit magic_link_path(MagicLink.generate_for(user))
  end
end
