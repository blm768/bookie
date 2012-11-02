require 'rubygems'
require 'bookie'

require 'date'

class BadDateError < RangeError

end

class JobsController < ApplicationController
  def index
    @jobs = Bookie::Database::Job#.select(:include => [:user, :system])
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
    end
    
    case params[:sort]
    when 'date'
      @jobs.order(:date)
      @last_sort = :date
    when 'wall_time'
      @jobs.order(:wall_time)
      @last_sort = :wall_time
    end
    
    @jobs = @jobs.all
    
    wall_time = 0
    cpu_time = 0
    @jobs.each do |job|
      wall_time += job.wall_time
      cpu_time += job.cpu_time
    end
    render :template => 'jobs/index',
      :locals => {
        :total_wall_time => wall_time,
        :total_cpu_time => cpu_time
      }
  end
end
