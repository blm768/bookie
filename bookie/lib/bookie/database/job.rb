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
      def self.by_time_range(time_range)
        if time_range.empty?
          self.none
        else
          time_range = time_range.exclusive
          where('jobs.end_time > ? AND jobs.start_time < ?', time_range.begin, time_range.end)
        end
      end

      ##
      #Similar to #by_time_range, but only includes jobs that are completely contained within the
      #time range
      def self.within_time_range(time_range)
        if time_range.empty?
          self.none
        else
          time_range = time_range.exclusive
          #The second "<=" operator _is_ intentional.
          #If the job's end_time is one second past the last value in the range, it
          #is still considered to be contained within time_range because it did not
          #run outside time_range; it only _stopped_ outside it.
          where('? <= jobs.start_time AND jobs.end_time <= ?', time_range.begin, time_range.end)
        end
      end

      ##
      #Produces a summary of the jobs in the given time interval
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
      #TODO: adjust.
      #TODO: is end_time considered inclusive or exclusive?
      #The time_range parameter is always treated as if time_range.exclude_end? is true.
      def self.summary(time_range = nil)
        jobs = self

        num_jobs = 0
        successful = 0
        cpu_time = 0.0
        memory_time = 0

        if time_range
          unless time_range.empty?
            time_range = time_range.exclusive

            #Any jobs that are completely within the time range can
            #be summarized as-is.
            jobs_within = jobs.within_time_range(time_range)
            #TODO: optimize into one query? (using pluck() with an SQL fragment?)
            num_jobs += jobs_within.count
            successful += jobs_within.where(:exit_code => 0).count
            cpu_time += jobs_within.sum(:cpu_time)
            memory_time += jobs_within.sum('jobs.memory * jobs.wall_time')

            #Any jobs that overlap an edge of the time range
            #must be clipped.
            [time_range.first, time_range.last].each do |time|
              jobs_overlapped = jobs.where('jobs.start_time < :1 AND :1 < jobs.end_time', time)
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
          end
        else
          #There's no time_range constraint; just summarize everything.
          #TODO: eliminate redundancy with the other code path?
          num_jobs = jobs.count
          successful = jobs.where(:exit_code => 0).count
          cpu_time = jobs.sum(:cpu_time)
          memory_time = jobs.sum('jobs.memory * jobs.wall_time')
        end

        return {
          :num_jobs => num_jobs,
          :successful => successful,
          :cpu_time => cpu_time.round,
          :memory_time => memory_time,
        }
      end

      before_save do
        write_attribute(:end_time, end_time)
      end

      validates_presence_of :user, :system, :cpu_time,
        :start_time, :wall_time, :memory, :exit_code, :command_name

      #TODO: validate integral type?
      validates :cpu_time, :wall_time, :memory,  numericality: { greater_than_or_equal_to: 0 }
    end
  end
end
