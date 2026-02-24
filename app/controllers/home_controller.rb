class HomeController < ApplicationController
  def index
    @rate = params[:rate].to_i
    @grouped_feeds = Feed.grouped_by_folder_for_home(rate: @rate)
    @feeds = @grouped_feeds.flat_map { |_, feeds| feeds }
    @pinned_count = Entry.pinned.count
  end
end
