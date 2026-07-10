class MagicLinkConsumptionsController < ApplicationController
  allow_unauthenticated_access only: :create

  def create
    magic_link = MagicLink.find_by_token(params[:magic_link_token])

    if magic_link
      magic_link.destroy!
      start_new_session_for magic_link.user
      redirect_to after_authentication_url
    else
      redirect_to new_session_path, alert: "リンクが無効または期限切れです。再度メールを送信してください。"
    end
  end
end
