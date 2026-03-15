class HomeController < ApplicationController
  def index
    @rate = params[:rate].to_i
    @grouped_subscriptions = Current.user.grouped_subscriptions_for_home(rate: @rate)
    @subscriptions = @grouped_subscriptions.flat_map { |_, subs| subs }
    @pinned_count = Current.user.pinned_entry_count
  end
end
