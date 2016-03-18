##
#Handles password resets and confirmations
#
#A confirmation is treated as a special case of a password reset.
class PasswordResetsController < ApplicationController
  before_filter :require_guest

  def new
    @action_name = 'Reset password'
  end

  #TODO: figure out why this is deleting the password hashes.
  def create
    web_user = WebUser.where(email: params[:email]).first
    if web_user
      message_type = if web_user.confirmed? then :reset_password else :confirmation end
      key = web_user.generate_reset_key
      web_user.save!
      #TODO: use deliver_now or deliver_later.
      WebUserMailer.send(message_type, web_user, key).deliver
    end
    flash_msg :notice, 'A message has been sent to the provided e-mail address.'
    redirect_to new_session_path
  end

  def edit
    id = params[:id]
    @reset_key = params[:key]
    if @reset_key.blank?
      flash_msg :error, 'No reset key provided'
      redirect_to root_path
      return
    end
    @web_user = WebUser.where(id: id).first
    #TODO: check errors, provide proper error codes, and so forth.

    return unless validate_reset_key_and_redirect(@web_user, @reset_key)

    @action_name = action_name_for(@web_user)
  end

  def update
    #The #find method would raise an exception for invalid user IDs, which
    #provides more information to an attacker than we'd like, even if
    #the exception details aren't displayed.
    @web_user = WebUser.where(id: params[:id]).first
    @reset_key = params[:key]

    return unless validate_reset_key_and_redirect(@web_user, @reset_key)

    @web_user.password = params[:password]
    @web_user.password_confirmation = params[:password_confirmation]
    if @web_user.valid?
      @web_user.clear_reset_key
      @web_user.save!
      flash_msg :notice, 'Password set.'
      redirect_to new_session_path
    else
      render action: 'edit'
    end
  end

  private

  #TODO: remove 'password' from string?
  def action_name_for(web_user)
    if web_user.confirmed?
      'Reset password'
    else
      'Set password'
    end
  end

  def validate_reset_key_and_redirect(web_user, reset_key)
    unless web_user && web_user.correct_reset_key?(reset_key)
      flash_msg :error, 'Invalid user or reset key.'
      redirect_to root_path
      return false
    end

    if web_user.reset_key_expired?
      flash_msg :error, 'This reset key has expired. Please request a new confirmation/reset key.'
      redirect_to new_password_reset_path
      return false
    end

    true
  end
end
