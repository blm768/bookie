require 'bookie'

module Bookie
  module Summary
    def self.summary(jobs)
      num_jobs = 0
      wall_time = 0
      cpu_time = 0
      successful_jobs = 0
      jobs.each do |job|
        num_jobs += 1
        wall_time += job.wall_time
        cpu_time += job.cpu_time
        successful_jobs += 1 if job.exit_code == 0
      end      
      return {
        jobs: num_jobs,
        wall_time: wall_time,
        cpu_time: cpu_time,
        success: Float(successful_jobs) / num_jobs,
      }
    end
  end
end