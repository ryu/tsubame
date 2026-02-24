class FoldersController < ApplicationController
  before_action :set_folder, only: [ :edit, :update, :destroy ]

  def index
    @folders = Folder.order(:name).includes(:feeds)
  end

  def new
    @folder = Folder.new
  end

  def create
    @folder = Folder.new(folder_params)
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
    @folder = Folder.find(params[:id])
  end

  def folder_params
    params.require(:folder).permit(:name)
  end
end
