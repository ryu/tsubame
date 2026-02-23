class HomeController < ApplicationController
  def index
    @rate = params[:rate].to_i
    @feeds = Feed.with_unreads.with_rate_at_least(@rate).order(:title)
    @pinned_count = Entry.pinned.count
  end
end
