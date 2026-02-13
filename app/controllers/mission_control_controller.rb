class MissionControlController < ActionController::Base
  include Authentication

  private
    def request_authentication
      session[:return_to_after_authenticating] = request.url
      redirect_to main_app.new_session_path
    end
end
