require "test_helper"

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

  setup { ActionController::Base.allow_forgery_protection = true }
  teardown { ActionController::Base.allow_forgery_protection = false }

  private

  def sign_in_as(user)
    visit magic_link_path(MagicLink.generate_for(user))
    click_button "ログイン"
  end
end
