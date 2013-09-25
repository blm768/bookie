class ApplicationController < ActionController::Base
  #TODO: restore!
  #before_filter :authenticate_web_user!

  protect_from_forgery with: :exception

  def redirect_back_or_to_root
    redirect_to :back
  rescue ActionController::RedirectBackError
    redirect_to root_path
  end
end
