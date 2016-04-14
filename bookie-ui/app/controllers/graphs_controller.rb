require 'bookie_database_all'

require 'date'

class GraphsController < ApplicationController
  before_filter :require_login

  FILTERS = {
    system: :text,
    user: :text,
    group: :text,
    #TODO: turn this into a selection box.
    system_type: :text,
    command_name: :text,
  }

  include FilterMixin

  def show
  end
end
