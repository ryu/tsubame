class UsersController < ApplicationController
  before_action :require_admin
  before_action :set_user, only: [ :edit, :update, :destroy ]

  def index
    @users = User.includes(:admin).order(:email_address)
  end

  def new
    @user = User.new
  end

  def create
    @user = User.new(user_params)
    if @user.save
      manage_admin_status
      redirect_to users_path, notice: "ユーザーを作成しました。"
    else
      render :new, status: :unprocessable_entity
    end
  end

  def edit
  end

  def update
    if @user.update(user_params)
      manage_admin_status
      redirect_to users_path, notice: "ユーザーを更新しました。"
    else
      render :edit, status: :unprocessable_entity
    end
  end

  def destroy
    if @user == Current.user
      redirect_to users_path, alert: "自分自身は削除できません。"
    else
      @user.destroy
      redirect_to users_path, notice: "ユーザーを削除しました。"
    end
  end

  private

  def require_admin
    redirect_to root_path, alert: "管理者権限が必要です。" unless Current.user.admin?
  end

  def set_user
    @user = User.find(params[:id])
  end

  def user_params
    params.require(:user).permit(:email_address)
  end

  def manage_admin_status
    if params[:admin] == "1"
      @user.create_admin unless @user.admin?
    elsif @user != Current.user
      @user.admin&.destroy
    end
  end
end
