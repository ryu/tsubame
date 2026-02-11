class FeedsController < ApplicationController
  def index
    @feeds = Feed.all.order(:title)
  end

  def new
    @feed = Feed.new
  end

  def create
    @feed = Feed.new(url: params.require(:feed).permit(:url)[:url])
    @feed.next_fetch_at = Time.current
    if @feed.save
      redirect_to feeds_path, notice: "フィードを追加しました。"
    else
      render :new, status: :unprocessable_entity
    end
  end

  def edit
    @feed = Feed.find(params[:id])
  end

  def update
    @feed = Feed.find(params[:id])
    if @feed.update(params.require(:feed).permit(:title, :fetch_interval_minutes))
      redirect_to feeds_path, notice: "フィードを更新しました。"
    else
      render :edit, status: :unprocessable_entity
    end
  end

  def destroy
    @feed = Feed.find(params[:id])
    @feed.destroy
    redirect_to feeds_path, notice: "フィードを削除しました。"
  end
end
