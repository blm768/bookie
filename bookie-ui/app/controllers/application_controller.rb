class ApplicationController < ActionController::Base
  protect_from_forgery with: :exception

  def flash_msg(type, msg)
    flash[type] ||= []
    flash[type] << msg
  end

  def flash_msg_now(type, msg)
    flash.now[type] ||= []
    flash.now[type] << msg
  end
end
