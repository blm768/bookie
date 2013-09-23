class WebUsersController < ApplicationController
  def index
    @web_users = WebUser.order(:email).to_a
  end

  def approve
    web_user = WebUser.find(params[:id].to_i)
    if web_user
      if web_user.approved?
        flash[:alert] = %{The user "#{user.email}" has already been approved."}
      else
        web_user.approved = true
        web_user.save!
        flash[:notice] = "User approved."
      end
    else
      flash[:notice] = "Unable to find the specified user."
    end 
    redirect_back_or_to_root
  end

  def destroy
    web_user = WebUser.find(params[:id].to_i)

    #Don't delete the last approved Web user.
    if WebUser.where(:approved => true).count <= 1 && web_user.approved?
      flash[:error] = 'Cannot delete user: there must always be at least one approved user.'
      redirect_back_or_to_root
      return
    end

    if current_web_user == web_user
      redirect_to new_web_user_session_path
    else
      redirect_back_or_to_root
    end
    web_user.delete
    flash[:notice] = 'User deleted.'
  end
end

