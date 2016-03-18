class SessionsController < ApplicationController
  def new
    if current_web_user
      flash_msg :alert, 'You are already logged in.'
      redirect_to root_path
      return
    end
  end

  def create
    web_user = WebUser.authenticate(params[:email], params[:password])
    if web_user
      reset_session
      session[:user_id] = web_user.id
      flash_msg :notice, 'Logged in.'
      redirect_to root_path
    else
      flash_msg :error, 'Invalid E-mail address or password.'
      redirect_to action: 'new'
    end
  end

  def destroy
    if current_web_user
      reset_session
      flash_msg :notice, 'Logged out.'
    else
      flash_msg :alert, 'You are not logged in.'
    end
    redirect_to new_session_path
  end
end
