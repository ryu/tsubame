class MagicLinksController < ApplicationController
  allow_unauthenticated_access only: :show

  # メールスキャナのプリフェッチでトークンが消費されないよう、show では消費しない
  def show
    @token = params[:token]
  end
end
