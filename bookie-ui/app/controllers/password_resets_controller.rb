##
#Handles password resets and confirmations
#
#A confirmation is treated as a special case of a password reset.
class PasswordResetsController < ApplicationController
  before_filter :require_guest

  def new
    @action_name = 'Reset password'
  end

  def create
    web_user = WebUser.where(:email => params[:email]).first
    if web_user
      message_type = if web_user.confirmed? then :reset_password else :confirmation end
      key = web_user.generate_reset_key
      web_user.save!
      WebUserMailer.send(message_type, web_user, key).deliver
    end
    flash[:notice] = 'A password-reset message has been sent to your e-mail address.'
    redirect_to new_session_path
  end

  def edit
    id = params[:id]
    @reset_key = params[:key]
    if @reset_key.blank?
      flash[:error] = 'No reset key provided'
      redirect_to root_path
      return
    end
    @web_user = WebUser.where(:id => id).first
    unless @web_user && @web_user.correct_reset_key?(@reset_key)
      flash[:error] = 'Invalid user or reset key'
      redirect_to root_path
      return
    end

    @action_name = action_name_for(@web_user)
  end

  def update
    #The #find method would raise an exception for invalid user IDs, which
    #provides more information to an attacker than we'd like, even if
    #the exception details aren't displayed.
    @web_user = WebUser.where(:id => params[:id]).first
    @reset_key = params[:key]

    unless @web_user && @web_user.correct_reset_key?(@reset_key)
      flash[:error] = 'Invalid user or reset key.' + " #{@web_user.reset_key_hash}"
      redirect_to root_path
      return
    end

    @action_name = action_name_for(@web_user)

    @web_user.password = params[:password]
    @web_user.password_confirmation = params[:password_confirmation]
    if @web_user.valid?
      @web_user.clear_reset_key
      @web_user.save!
      flash[:notice] = "Password #{@action_name}."
      redirect_to new_session_path
    else
      render :action => 'edit'
    end
  end

  def action_name_for(web_user)
    if web_user.confirmed?
      'reset'
    else
      'set'
    end
  end
end
