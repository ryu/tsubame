class FeedEventLogSubscriber
  def emit(event)
    Rails.logger.info({ event: event[:name], **event[:payload] }.to_json)
  end
end

Rails.event.subscribe(FeedEventLogSubscriber.new) { |event| event[:name].start_with?("feed.") }
