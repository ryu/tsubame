class FeedExportsController < ApplicationController
  def show
    send_data Feed.to_opml,
      filename: "subscriptions.opml",
      type: "application/xml",
      disposition: "attachment"
  end
end
