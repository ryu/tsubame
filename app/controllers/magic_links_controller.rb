class MagicLinksController < ApplicationController
  allow_unauthenticated_access only: :show

  def show
    magic_link = MagicLink.find_by_token(params[:token])

    if magic_link
      magic_link.destroy!
      start_new_session_for magic_link.user
      redirect_to after_authentication_url
    else
      redirect_to new_session_path, alert: "リンクが無効または期限切れです。再度メールを送信してください。"
    end
  end
end
