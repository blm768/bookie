require 'bookie'

module Bookie
  module Summary
    def self.summary(jobs, start_time = nil, end_time = nil)
      num_jobs = 0
      wall_time = 0
      cpu_time = 0
      successful_jobs = 0
      jobs.find_each do |job|
        num_jobs += 1
        wall_time += job.wall_time
        cpu_time += job.cpu_time
        successful_jobs += 1 if job.exit_code == 0
      end
      
      total_cpu_time = 0
      #Find all the servers within the time range.
      servers = Bookie::Database::Server
      if start_time
        assert end_time
        servers = servers.where(
          'start_time < ? AND (end_time IS NULL OR end_time > ?)',
          end_time,
          start_time)
      end
      servers.find_each do |server|
        server_start_time = nil
        server_end_time = nil
        #Is there a date range constraint?
        if start_time
          server_start_time = [server.start_time, start_time].max
          server_end_time = [server.end_time. end_time].min if server.end_time
        else
          server_start_time = server.start_time
          server_end_time = server.end_time
        end
        #If the server doesn't have an end time, set it to a logical value.
        server_end_time ||= end_time || Time.new
        total_cpu_time += server.cores * (server_end_time - server_start_time)
      end
      
      return {
        :jobs => num_jobs,
        :wall_time => wall_time,
        :cpu_time => cpu_time,
        :success =>  if num_jobs == 0 then 0 else Float(successful_jobs) / num_jobs end,
        :total_cpu_time => total_cpu_time,
        :used_cpu_time => if total_cpu_time == 0 then 0 else cpu_time / total_cpu_time end,
      }
    end
  end
end