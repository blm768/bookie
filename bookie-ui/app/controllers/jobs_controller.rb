require 'rubygems'
require 'bookie'

class JobsController < ApplicationController
  def index
    @jobs = Bookie::Database::Job.all
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
