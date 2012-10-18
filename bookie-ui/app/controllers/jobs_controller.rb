require 'rubygems'
require 'bookie'

require 'date'

class JobsController < ApplicationController
  def index
    @jobs = Bookie::Database::Job
    case params[:filter_type]
      when 'date'
        date_text = params[:filter_value]
        if date_text && date_text.length > 0
          bad_format = false
          date_text.strip!
          fields = date_text.split('-').map{ |s| Integer(s) } rescue bad_format = true
          date = Date.new(*fields) rescue bad_format = true
          next_unit = case fields.length
            when 1
              :next_year
            when 2
              :next_month
            when 3
              :next_day
          end
          if bad_format
            flash.now[:error] = "Invalid date: #{date_text}"
          else
            @jobs = @jobs.where(
              "? <= date AND date < ?",
              date.strftime("%Y-%m-%d"),
              date.send(next_unit).strftime("%Y/%m/%d"))
          end
        else
          flash.now[:error] = "No date specified"
        end
      when 'server'
        server = Bookie::Database::Server.where('name = ?', params[:filter_value]).first
        if server
          @jobs = @jobs.where('server_id = ?', server.id)
        else
          @jobs = Bookie::Database::Job.limit(0)
        end
      when 'user'
        #To do: handle group changes.
        user = Bookie::Database::User.where('name = ?', params[:filter_value]).first
        if user
          @jobs = @jobs.where('user_id = ?', user.id)
        else
          @jobs = Bookie::Database::Job.limit(0)
        end
      when 'group'
        group = Bookie::Database::Group.where('name = ?', params[:filter_value]).first
        if group
          @jobs = @jobs.joins(:user).where('user_id = users.id && group_id = ?', group.id)
        else
          @jobs = Bookie::Database::Job.limit(0)
        end
    end
    
    case params[:sort]
      when 'date'
        @jobs.order(:date)
      when 'wall_time'
        @jobs.order(:wall_time)
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
