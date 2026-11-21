class MagicLinksController < ApplicationController
  allow_unauthenticated_access only: :show

  def show
    @token = params[:token]
  end
end
