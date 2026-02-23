class PasswordsController < ApplicationController
  rate_limit to: 5, within: 1.minute, only: :update,
    with: -> { redirect_to edit_password_path, alert: "しばらく待ってから再試行してください。" }

  def edit
  end

  def update
    if Current.user.update(password_params)
      Current.user.invalidate_other_sessions!(except: Current.session)
      redirect_to root_path, notice: "パスワードを変更しました。"
    else
      render :edit, status: :unprocessable_entity
    end
  end

  private

  def password_params
    params.expect(user: [ :password_challenge, :password, :password_confirmation ])
  end
end
