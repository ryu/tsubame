class FoldersController < ApplicationController
  before_action :set_folder, only: [ :edit, :update, :destroy ]

  def index
    @folders = Current.user.folders.order(:name).includes(:subscriptions)
  end

  def new
    @folder = Current.user.folders.new
  end

  def create
    @folder = Current.user.folders.new(folder_params)
    if @folder.save
      redirect_to folders_path, notice: "フォルダを作成しました。"
    else
      render :new, status: :unprocessable_entity
    end
  end

  def edit
  end

  def update
    if @folder.update(folder_params)
      redirect_to folders_path, notice: "フォルダを更新しました。"
    else
      render :edit, status: :unprocessable_entity
    end
  end

  def destroy
    @folder.destroy
    redirect_to folders_path, notice: "フォルダを削除しました。"
  end

  private

  def set_folder
    @folder = Current.user.folders.find(params[:id])
  end

  def folder_params
    params.require(:folder).permit(:name)
  end
end
