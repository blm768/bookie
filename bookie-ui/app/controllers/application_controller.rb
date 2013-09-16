class ApplicationController < ActionController::Base
  protect_from_forgery with: :exception

  def flash_msg(category, msg)
    flash_value = flash[category]
    if flash_value == nil
      flash_value = [msg]
      flash[category] = flash_value
    elsif flash_value.is_a?String
      #Something outside the main app code has created a flash message; include it in the array.
      flash_value = [flash_value, msg]
      flash[category] = flash_value
    else
      flash_value << msg
    end
  end

  def flash_msg_now(category, msg)
    flash_value = flash.now[category]
    if flash_value == nil
      flash_value = [msg]
      flash.now[category] = flash_value
    elsif flash_value.is_a?String
      #Something outside the main app code has created a flash message; include it in the array.
      flash_value = [flash_value, msg]
      flash.now[category] = flash_value
    else
      flash_value << msg
    end
  end
end
