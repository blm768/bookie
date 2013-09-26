class WebUsersController < ApplicationController
  before_filter :require_login

  def new
    @web_user = WebUser.new
  end

  def create
    user_params = params[:web_user].permit(:email)
    @web_user = WebUser.new(user_params)
    if @web_user.valid?
      key = @web_user.generate_reset_key
      @web_user.save!
      WebUserMailer.confirmation(@web_user, key).deliver
      flash[:notice] = 'User created.'
      redirect_to web_users_path
    else
      render :action => 'new'
    end
  end

  def index
    @web_users = WebUser.where(nil)
  end

  def destroy
    redirect_to web_users_path
    web_user = WebUser.where(:id => params[:id]).first
    unless web_user
      flash[:error] = 'Unable to find user.'
      return
    end

    confirmed_web_users = WebUser.where('web_users.password_hash IS NOT NULL')
    if confirmed_web_users.count == 1 && web_user.confirmed?
      flash[:error] = 'Unable to delete user: there must always be at least one confirmed user.'
    else
      flash[:notice] = 'User deleted.'
      web_user.destroy
    end
  end
end
