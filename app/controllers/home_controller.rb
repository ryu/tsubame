class HomeController < ApplicationController
  def index
    @feeds = Feed.with_unreads.order(:title)
    @pinned_count = Entry.pinned.count
  end
end
