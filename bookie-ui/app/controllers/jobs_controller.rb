require 'rubygems'
require 'bookie'

class JobsController < ApplicationController
  def index
    @jobs = Bookie::Database::Job
    case params[:filter_type]
      when 'user'
        #To do: handle group changes.
        user = Bookie::Database::User.where('name = ?', params[:filter_value]).first
        if user
          @jobs = @jobs.where(:user_id => user.id)
        else
          @jobs = Bookie::Database::Job.limit(0)
        end
      when 'group'
        #To do: handle group changes.
        group = Bookie::Database::Group.where('name = ?', params[:filter_value]).first
        if group
          @jobs = @jobs.joins(:user).where('user_id = users.id && group_id = ?', group.id)
        else
          @jobs = Bookie::Database::Job.limit(0)
        end
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
