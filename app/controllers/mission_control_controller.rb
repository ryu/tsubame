class MissionControlController < ActionController::Base
  include Authentication

  before_action :require_admin

  private
    def require_admin
      redirect_to main_app.root_path, alert: "管理者権限が必要です。" unless Current.user&.admin?
    end

    def request_authentication
      session[:return_to_after_authenticating] = request.url
      redirect_to main_app.new_session_path
    end
end
