require 'bookie_database_all'

class SystemsController < ApplicationController
  before_filter :require_login

  def index
    @systems = Bookie::Database::System.order(:name)
  end

  #TODO: implement.
  def show
    #@system = Bookie::Database::System.find
  end

  def new
    @system = Bookie::Database::System.new
  end

  def create
    sys_params = params[:system].permit(:hostname, :system_type)
    @system = Bookie::Database::System.new(sys_params)
    if @system.valid?
      @system.save!
      flash_msg :notice, 'System created.'
      redirect_to systems_path
    else
      render action: 'new'
    end
  end
end

