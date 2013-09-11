class ApplicationController < ActionController::Base
  protect_from_forgery with: :exception

  def flash_msg(catetory, msg)
    flash_value = flash[category]
    if flash_value
      flash_value << "\n#{msg}"
    else
      flash[category] = msg
    end
  end

  def flash_msg_now(type, msg)
    flash_value = flash.now[category]
    if flash_value
      flash_value << "\n#{msg}"
    else
      flash.now[category] = msg
    end
  end
end
