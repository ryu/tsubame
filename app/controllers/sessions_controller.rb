class SessionsController < ApplicationController
  allow_unauthenticated_access only: %i[ new create ]
  rate_limit to: 10, within: 3.minutes, only: :create, name: "per-ip",
             with: -> { redirect_to new_session_path, alert: "しばらく時間をおいてから試してください。" }
  rate_limit to: 3, within: 10.minutes, only: :create, name: "per-email",
             by: -> { params[:email_address].to_s.strip.downcase },
             with: -> { redirect_to new_session_path, alert: "しばらく時間をおいてから試してください。" }

  def new
  end

  def create
    user = User.find_by(email_address: params[:email_address])
    if user
      token = MagicLink.generate_for(user)
      MagicLinkMailer.with(user: user, token: token).magic_link_email.deliver_later
    end
    redirect_to new_session_path, notice: "ログインリンクをメールで送信しました。"
  end

  def destroy
    terminate_session
    redirect_to new_session_path, status: :see_other
  end
end
