class ApplicationController < ActionController::Base
  before_filter :authenticate_web_user!

  protect_from_forgery with: :exception

  def redirect_back_or_to_root
    redirect_to :back
  rescue
    redirect_to root_path
  end
end
