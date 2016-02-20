require 'active_record'

require 'bookie/database/lock.rb'
require 'bookie/database/user.rb'
require 'bookie/database/system.rb'

module Bookie
  module Database
    ##
    #A reported job
    #
    #The various filter methods can be chained to produce more complex queries.
    #
    #===Examples
    #  Bookie::Database::Job.by_user_name('root').by_system_name('localhost').find_each do |job|
    #    puts job.inspect
    #  end
    #
    class Job < ActiveRecord::Base
      belongs_to :user
      belongs_to :system
      has_one :system_type, :through => :system

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
          jobs = jobs.where('jobs.end_time > ?', time_max)
        end
        if time_max then
          jobs = jobs.where('jobs.start_time <= ?', time_min)
        end

        jobs
      end

      ##
      #Similar to #by_time_range, but only includes jobs that are completely contained within the
      #time range
      def self.within_time_range(time_min, time_max)
        return self.none if time_min && time_max && time_max <= time_min

        jobs = self
        if time_min
          jobs = jobs.where('jobs.start_time >= ?', time_min)
        end
        if time_max
          #TODO: make sure unit tests cover this fully.
          jobs = jobs.where('jobs.start_time < :1 AND jobs.end_time <= :1', time_max)
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
        #TODO: optimize into one query? (using pluck() with an SQL fragment?)
        num_jobs += jobs_within.count
        successful += jobs_within.where(:exit_code => 0).count
        cpu_time += jobs_within.sum(:cpu_time)
        memory_time += jobs_within.sum('jobs.memory * jobs.wall_time')

        #Any jobs that overlap an edge of the time range
        #must be clipped.
        #TODO: make this simpler without double-counting jobs?
        #TODO: unit-test to make sure jobs aren't double-counted?
        #TODO: just do an OR or a union to get both sides at once?
        jobs_left, jobs_right, jobs_both = nil
        if time_min then
          #TODO: cut out jobs that overlap both.
          #jobs_left = jobs.where('jobs.start_time < ?', time_min)
        end
        if time_max then
          #jobs_right = jobs.where('
        end
        [jobs_left, jobs_right, jobs_both].each do |jobs_overlapped|
          next if jobs_overlapped == nil

          jobs_overlapped.find_each do |job|
            num_jobs += 1
            successful += 1 if job.exit_code == 0

            next if job.wall_time == 0

            start_time = [job.start_time, time_range.begin].max
            end_time = [job.end_time, time_range.end].min
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

      #TODO: validate integral type?
      validates :cpu_time, :wall_time, :memory,  numericality: { greater_than_or_equal_to: 0 }

      #TODO: validate the existence of a system capacity entry covering the job's time interval?
    end
  end
end
