require 'bookie_database_all'

require 'date'

class GraphsController < ApplicationController
  FILTERS = {
    'System' => {:types => [:text]},
    'User' => {:types => [:text]},
    'Group' => {:types => [:text]},
    'System type' => {:types => [:sys_type]},
    'Command name' => {:types => [:text]},
  }
  
  include FilterMixin

  def show       
    respond_to do |format|
      format.html
    end
  end
end
