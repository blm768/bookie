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
      servers = Bookie::Database::Server
      if start_time
        assert end_time
        servers = servers.where(
          'start_time < ? AND (end_time IS NULL OR end_time > ?)',
          end_time,
          start_time)
      end
      
      return {
        :jobs => num_jobs,
        :wall_time => wall_time,
        :cpu_time => cpu_time,
        :success => Float(successful_jobs) / num_jobs,
        :total_cpu_time => total_cpu_time,
        :used_cpu_time => if total_cpu_time == 0 then 'N/A' else cpu_time / total_cpu_time end,
      }
    end
  end
end