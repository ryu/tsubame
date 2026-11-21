require "test_helper"

# Capybara 3.40 resets sessions with Storage.clearDataForOrigin(origin: "*"),
# which recent Chrome rejects as an invalid URL. Clear the app server's origin instead.
# Remove once a Capybara release fixes this.
module ClearStorageForAppOrigin
  private
    def execute_cdp(cmd, params = {})
      if cmd == "Storage.clearDataForOrigin" && params[:origin] == "*"
        origin = Capybara.current_session.server&.base_url
        return unless origin
        params = params.merge(origin: origin)
      end

      super
    end
end
Capybara::Selenium::Driver::ChromeDriver.prepend ClearStorageForAppOrigin

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
    click_button "ログイン"
  end
end
