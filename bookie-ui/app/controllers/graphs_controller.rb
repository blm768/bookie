require 'bookie_database_all'

require 'date'

class GraphsController < ApplicationController
  FILTER_ARG_COUNTS = {
    'System' => 1,
    'User' => 1,
    'Group' => 1,
    'System type' => 1,
    'Command name' => 1,
  }
  
  include FilterMixin

  def show       
    #Passed to the view to make the filter form's contents persistent
    @prev_filters = []
    
    #To do: error on empty fields?
    each_filter(FILTER_ARG_COUNTS) do |type, values|
      @prev_filters << [type, values]
    end
    
    respond_to do |format|
      format.html
    end
  end
end
