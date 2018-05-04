require 'bookie/database'

module Bookie::Database
  ##
  #Represents a job record
  class Job < Model
    belongs_to :user
    belongs_to :system
    has_one :system_type, through: :system

    ##
    #The time at which the job ended
    def end_time
      return start_time + wall_time
    end

    ##
    #Finds all jobs that were running at some point in a given time range
    #
    #time_min and/or time_max may be nil, which represents infinity.
    def self.by_time_range(time_min, time_max)
      return self.none if time_min && time_max && time_max <= time_min

      jobs = self
      if time_min then
        #TODO: how to handle zero-wall-time jobs at the beginning of the range?
        jobs = jobs.where('jobs.end_time > ?', time_min)
      end
      if time_max then
        jobs = jobs.where('jobs.start_time < ?', time_max)
      end

      jobs
    end

    ##
    #Similar to #by_time_range, but only includes jobs that are completely contained within the
    #time range
    #
    #For jobs with zero <code>wall_time</code>, jobs at <code>time_min</code>
    #are included, but jobs at <code>time_max</code> are excluded.
    def self.within_time_range(time_min, time_max)
      return self.none if time_min && time_max && time_max <= time_min

      jobs = self
      if time_min
        jobs = jobs.where('jobs.start_time >= ?', time_min)
      end
      if time_max
        #Jobs with start_time and end_time equal to time_max need to be excluded.
        #TODO: make sure unit tests cover this fully.
        jobs = jobs.where('jobs.start_time < :time AND jobs.end_time <= :time', time: time_max)
      end

      jobs
    end

    ##
    #Produces a summary of the jobs in the given time interval
    #
    #time_min and/or time_max may be nil, which represents infinity.
    #
    #Returns a hash with the following fields:
    #- <tt>:num_jobs</tt>: the number of jobs in the interval
    #- <tt>:successful</tt>: the number of jobs that have completed successfully
    #- <tt>:cpu_time</tt>: the total CPU time used
    #- <tt>:memory_time</tt>: the sum of memory * wall_time for all jobs in the interval
    #
    #This method should probably not be chained with other queries that filter by start/end time.
    #It also doesn't work with the limit() method.
    #
    def self.summary(time_min, time_max)
      jobs = self

      num_jobs = 0
      successful = 0
      cpu_time = 0.0
      memory_time = 0

      #Any jobs that are completely within the time range can
      #be summarized as-is.
      jobs_within = jobs.within_time_range(time_min, time_max)
      fields_within = jobs_within.select(
        'COUNT(*) as num_jobs,
        SUM(jobs.cpu_time) as cpu_time,
        SUM(jobs.memory * jobs.wall_time) as memory_time'
      ).first
      #Did we actually pick up any jobs?
      if fields_within && fields_within.num_jobs > 0 then
        num_jobs += fields_within.num_jobs
        cpu_time += fields_within.cpu_time
        memory_time += fields_within.memory_time
      end
      successful += jobs_within.where(exit_code: 0).count

      #Any jobs that overlap an one or both edges of the time range
      #must be clipped.
      #TODO: unit-test to make sure jobs aren't double-counted?
      jobs_on_edges = nil
      [time_min, time_max].each do |edge|
        jobs_on_edge = jobs.where('jobs.start_time < :edge AND :edge < jobs.end_time', edge: edge)
        if jobs_on_edges then
          #Based on http://stackoverflow.com/questions/6686920/activerecord-query-union
          #TODO: find a cleaner solution?
          jobs_on_edges = jobs.from("(#{jobs_on_edges.to_sql} UNION #{jobs_on_edge.to_sql}) as jobs")
        else
          jobs_on_edges = jobs_on_edge
        end
      end
      if jobs_on_edges
        jobs_on_edges.find_each do |job|
          num_jobs += 1
          successful += 1 if job.exit_code == 0

          next if job.wall_time == 0

          start_time = [job.start_time, time_min].max if time_min
          end_time = [job.end_time, time_max].min if time_max
          clipped_wall_time = end_time.to_i - start_time.to_i
          cpu_time += Float(job.cpu_time * clipped_wall_time) / job.wall_time
          memory_time += job.memory * clipped_wall_time
        end
      end

      {
        num_jobs: num_jobs,
        successful: successful,
        cpu_time: cpu_time.round,
        memory_time: memory_time,
      }
    end

    before_save do
      write_attribute(:end_time, end_time)
    end

    validates :user, :system, :cpu_time,
      :start_time, :wall_time, :memory, :exit_code, presence: true

    validates :command_name, exclusion: { in: [nil] }

    validates :cpu_time, :wall_time, :memory,  numericality: { greater_than_or_equal_to: 0 }
  end
end
