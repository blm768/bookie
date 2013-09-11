require 'bookie_database_all'

class UsersController < ApplicationController
  before_filter :authenticate_web_user!

  FILTERS = {
    'Group' => [:text]
  }
  
  include FilterMixin

  def index
    users = Bookie::Database::User.order(:name)

    @prev_filters = []

    each_filter(FILTERS) do |type, values, valid|
      @prev_filters << [type, values]
      next unless valid
      case type
      when 'Group'
        users = users.by_group_name(values[0])
      end
    end

    @users = users
  end
end

