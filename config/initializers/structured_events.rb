# Rails.event has no default subscriber, so feed crawl events would otherwise go
# nowhere. Emit them as single-line JSON for grepping and future log shipping.
class FeedEventLogSubscriber
  def emit(event)
    Rails.logger.info({ event: event[:name], **event[:payload] }.to_json)
  end
end

Rails.event.subscribe(FeedEventLogSubscriber.new) { |event| event[:name].start_with?("feed.") }
