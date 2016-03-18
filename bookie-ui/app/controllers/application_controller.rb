class ApplicationController < ActionController::Base
  protect_from_forgery with: :exception

  #Use with caution (if at all); if the user is coming from
  #certain pages, such as /password_resets/edit, redirecting
  #back will cause confusing flash messages.
  def redirect_back_or_to_root
    redirect_to :back
  rescue ActionController::RedirectBackError
    redirect_to root_path
  end

  def current_web_user
    user_id = session[:user_id]
    #TODO: if #current_web_user is called many times with an invalid
    #user_id in the session, it may cause a lot of superfluous queries.
    #Should we fix that?
    @current_web_user ||= WebUser.where(id: user_id).first if user_id
  end

  helper_method :current_web_user

  def flash_msg(type, message)
    append_flash_msg(flash, type, message)
  end

  def flash_msg_now(type, message)
    append_flash_msg(flash.now, type, message)
  end

  private

  def append_flash_msg(flash_hash, type, message)
    messages = flash_hash[type]
    raise messages unless messages.blank?
    if messages.blank?
      flash_hash[type] = messages = []
    end
    messages << message
  end

  def require_login
    unless current_web_user
      flash_msg :error, 'You must log in before continuing.'
      redirect_to new_session_path
    end
  end

  def require_guest
    if current_web_user
      flash_msg :alert, 'You are already logged in.'
      redirect_to root_path
    end
  end
end
