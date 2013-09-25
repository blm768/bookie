##
#Handles password resets and confirmations
class PasswordResetsController < ApplicationController
  def edit
    @email = params[:email]
    if @email.blank?
      flash[:error] = 'No E-mail address provided'
      redirect_to root_path
      return
    end
    @reset_key = params[:key]
    if @reset_key.blank?
      flash[:error] = 'No reset key provided'
      redirect_to root_path
      return
    end
    @web_user = WebUser.find_by(:email => @email)
    unless @web_user && @web_user.correct_reset_key?(@reset_key)
      flash[:error] = 'Invalid user or reset key'
      redirect_to root_path
      return
    end
  end

  def update
    @web_user = WebUser.find(params[:id])
    web_user_params = params[:web_user]
    reset_key = web_user_params[:key]

    unless @web_user.correct_reset_key?(reset_key)
      flash[:error] = 'Invalid reset key.'
      render :action => 'edit'
      return
    end

    @web_user.update(web_user_params.permit(:password, :password_confirmation))
    if @web_user.valid?
      @web_user.clear_reset_key
      @web_user.save!
      flash[:notice] = 'Password set.'
      #TODO: redirect to sign-in path.
      redirect_to root_path
    else
      render :action => 'edit'
    end
  end
end
