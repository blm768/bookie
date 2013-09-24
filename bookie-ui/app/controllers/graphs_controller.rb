require 'bookie_database_all'

require 'date'

class GraphsController < ApplicationController
  FILTERS = {
    :system => :text,
    :user => :text,
    :group => :text,
    #TODO: turn this into a selection box.
    :system_type => :text,
    :command_name => :text,
  }
  
  include FilterMixin

  def index
    respond_to do |format|
      format.html
    end
  end
end
