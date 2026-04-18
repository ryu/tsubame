class MagicLinkMailer < ApplicationMailer
  def magic_link_email
    @user = params[:user]
    @url = magic_link_url(params[:token])
    mail(to: @user.email_address, subject: "Tsubame ログインリンク")
  end
end
