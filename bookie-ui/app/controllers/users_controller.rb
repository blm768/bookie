require 'bookie_database_all'

#TODO: make these pages useful or remove them.
class UsersController < ApplicationController
  before_filter :require_login

  def index
    users = Bookie::Database::User.order(:name)
    @users = users
  end
end

