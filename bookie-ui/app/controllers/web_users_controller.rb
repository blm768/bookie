class WebUsersController < ApplicationController
  def index
    @web_users = WebUser.all
  end

  def destroy
    web_user = WebUser.find(params[:id].to_i)

    #Don't delete the last approved Web user.
    if WebUser.where(:approved => :true).count <= 1 && web_user.approved?
      flash[:error] = 'Cannot delete user: there must always be at least one approved user.'
      redirect_to :back
      return
    end

    #TODO: how to handle deletion of logged-in users?

    web_user.delete
    flash[:notice] = 'User deleted.'
    redirect_to :back
  end
end
