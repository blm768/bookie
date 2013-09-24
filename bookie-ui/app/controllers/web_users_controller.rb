class WebUsersController < ApplicationController
  def index
    @web_users = WebUser.order(:email).to_a
  end

  def destroy
    web_user = WebUser.find(params[:id].to_i)

    #Don't delete the last confirmed Web user.
    if WebUser.where('web_users.confirmed_at IS NOT NULL').count <= 1 && web_user.confirmed_at != nil
      flash[:error] = 'Cannot delete user: there must always be at least one confirmed user.'
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

