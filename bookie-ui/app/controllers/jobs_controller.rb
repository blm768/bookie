require 'rubygems'

require 'date'

class BadDateError < RangeError

end

class JobsController < ApplicationController
  def index
    #To do: optimize as local variable?
    jobs = Bookie::Database::Job
    @systems = Bookie::Database::System
        
    summary_start_time = nil
    summary_end_time = nil
    
    val = params[:filter_value]
    val = val.strip if val
    case params[:filter_type]
    when 'start_time'
      
    when 'system'
      jobs = jobs.by_system_name(params[:filter_value])
      @last_filter = :server
      @last_filter_value = val
    when 'user'
      jobs = Bookie::Filter::by_user(jobs, val)
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
    
    @jobs_summary = jobs.summary(summary_start_time, summary_end_time)
    @systems_summary = @systems.summary(summary_start_time, summary_end_time)
    
    render :template => 'jobs/index'
  end
end
