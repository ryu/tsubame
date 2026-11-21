require "test_helper"

module ClearStorageForAppOrigin
  PATCHED_CAPYBARA_VERSION = Gem::Version.new("3.40.0")

  def self.verify_still_needed!
    return if Gem::Version.new(Capybara::VERSION) <= PATCHED_CAPYBARA_VERSION

    raise <<~MESSAGE
      Capybara #{Capybara::VERSION} is newer than the version ClearStorageForAppOrigin patches (#{PATCHED_CAPYBARA_VERSION}).
      If it no longer sends Storage.clearDataForOrigin with origin "*" (teamcapybara/capybara#2865), delete ClearStorageForAppOrigin.
      Otherwise bump PATCHED_CAPYBARA_VERSION. See ryu/tsubame#115.
    MESSAGE
  end

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
ClearStorageForAppOrigin.verify_still_needed!
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
