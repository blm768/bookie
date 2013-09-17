class WebUsersController < ApplicationController
  def index
    @web_users = WebUser.all
  end
end
