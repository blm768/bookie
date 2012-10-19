require 'rubygems'
require 'bookie'

require 'date'

class BadDateError < RangeError

end

class JobsController < ApplicationController
  def index
    @jobs = Bookie::Database::Job
    val = params[:filter_value].strip
    case params[:filter_type]
      when 'date'
        #To do: remove copy?
        date_text = val
        if date_text && date_text.length > 0
          begin
            fields = date_text.split('-').map{ |s| Integer(s, 10) } rescue raise(BadDateError)
            date = Date.new(*fields) rescue raise(BadDateError)
            next_unit = case fields.length
              when 1
                :next_year
              when 2
                :next_month
              when 3
                :next_day
            end
          rescue BadDateError
            flash.now[:error] = "Invalid date: #{date_text}"
          else
            @jobs = @jobs.where(
              "? <= date AND date < ?",
              date.strftime("%Y-%m-%d"),
              date.send(next_unit).strftime("%Y/%m/%d"))
            @last_filter = :date
            @last_filter_value = val
          end
        else
          flash.now[:error] = "No date specified"
        end
      when 'server'
        server = Bookie::Database::Server.where('name = ?', val).first
        if server
          @jobs = @jobs.where('server_id = ?', server.id)
        else
          @jobs = Bookie::Database::Job.limit(0)
        end
        @last_filter = :server
        @last_filter_value = val
      when 'user'
        #To do: handle group changes.
        user = Bookie::Database::User.where('name = ?', params[:filter_value]).first
        if user
          @jobs = @jobs.where('user_id = ?', user.id)
        else
          @jobs = Bookie::Database::Job.limit(0)
        end
        @last_filter = :user
        @last_filter_value = val
      when 'group'
        group = Bookie::Database::Group.where('name = ?', params[:filter_value]).first
        if group
          @jobs = @jobs.joins(:user).where('user_id = users.id && group_id = ?', group.id)
        else
          @jobs = Bookie::Database::Job.limit(0)
        end
        @last_filter = group
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
