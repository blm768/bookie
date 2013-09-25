class ApplicationController < ActionController::Base
  protect_from_forgery with: :exception

  def redirect_back_or_to_root
    redirect_to :back
  rescue ActionController::RedirectBackError
    redirect_to root_path
  end

  def current_web_user
    #TODO: how to handle users deleted mid-session?
    user_id = session[:user_id]
    @current_web_user ||= WebUser.find(user_id) if user_id
  end

  helper_method :current_web_user

  private

  def require_login
    unless current_web_user
      flash[:error] = 'You must log in before continuing.'
      redirect_to new_session_path
    end
  end
end
