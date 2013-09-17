class ApplicationController < ActionController::Base
  before_filter :authenticate_web_user!

  protect_from_forgery with: :exception
end
