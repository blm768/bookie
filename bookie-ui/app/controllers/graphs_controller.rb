require 'bookie_database_all'

require 'date'

class GraphsController < ApplicationController
  before_filter :authenticate_web_user!

  FILTERS = {
    'System' => [:text],
    'User' => [:text],
    'Group' => [:text],
    'System type' => [:sys_type],
    'Command name' => [:text],
  }
  
  include FilterMixin

  def index
    respond_to do |format|
      format.html
    end
  end
end
