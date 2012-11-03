require 'rubygems'
require 'bookie'

require 'date'

class BadDateError < RangeError

end

class JobsController < ApplicationController
  def index
    #To do: optimize as local variable?
    @jobs = Bookie::Database::Job
    val = params[:filter_value]
    val = val.strip if val
    case params[:filter_type]
    when 'start_time'
      
    when 'system'
      @jobs = Bookie::Filter::by_system(@jobs, val)
      @last_filter = :server
      @last_filter_value = val
    when 'user'
      @jobs = Bookie::Filter::by_user(@jobs, val)
      @last_filter = :user
      @last_filter_value = val
    when 'group'
      @jobs = Bookie::Filter::by_group(@jobs, val)
      @last_filter = :group
      @last_filter_value = val
    when 'system'
      @jobs = Bookie::Filter::by_system(@jobs, val)
      @last_filter = :system
      @last_filter_value = val
    end
    
    case params[:sort]
    when 'date'
      @jobs = @jobs.order(:end_time)
      @last_sort = :date
    when 'wall_time'
      @jobs = @jobs.order(:wall_time)
      @last_sort = :wall_time
    end
    
    @jobs = @jobs
    
    @summary = Bookie::Summary::summary(@jobs)
    
    render :template => 'jobs/index'
  end
end
