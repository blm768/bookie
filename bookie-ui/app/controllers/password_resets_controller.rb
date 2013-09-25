##
#Handles password resets and confirmations
class PasswordResetsController < ApplicationController
  #TODO: create #new and #create actions

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
    reset_key = params[:key]

    unless @web_user.correct_reset_key?(reset_key)
      flash[:error] = 'Invalid reset key.'
      render :action => 'edit'
      return
    end

    @web_user.update(params[:web_user].permit(:password, :password_confirmation))
    if @web_user.valid?
      @web_user.clear_reset_key
      @web_user.save!
      flash[:notice] = 'Password set.'
      redirect_to new_session_path
    else
      render :action => 'edit'
    end
  end
end
