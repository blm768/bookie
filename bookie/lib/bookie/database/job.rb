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
      
      ##
      #The time at which the job ended
      def end_time
        return start_time + wall_time
      end

      #To consider: disable #end_time= ?
      
      def self.by_user(user)
        where('jobs.user_id = ?', user.id)
      end
      
      ##
      #Filters by user name
      def self.by_user_name(user_name)
        joins(:user).where('users.name = ?', user_name)
      end
      
      def self.by_system(system)
        where('jobs.system_id = ?', system.id)
      end

      ##
      #Filters by system name
      def self.by_system_name(system_name)
        joins(:system).where('systems.name = ?', system_name)
      end
      
      ##
      #Filters by group name
      def self.by_group_name(group_name)
        group = Group.find_by_name(group_name)
        return joins(:user).where('users.group_id = ?', group.id) if group
        self.none
      end
      
      ##
      #Filters by system type
      def self.by_system_type(system_type)
        joins(:system).where('systems.system_type_id = ?', system_type.id)
      end
      
      ##
      #Filters by command name
      def self.by_command_name(c_name)
        where('jobs.command_name = ?', c_name)
      end
      
      ##
      #Filters by a range of start times
      def self.by_start_time_range(time_range)
        where('? <= jobs.start_time AND jobs.start_time < ?', time_range.first, time_range.last)
      end
      
      ##
      #Filters by a range of end times
      def self.by_end_time_range(time_range)
        where('? <= jobs.end_time AND jobs.end_time < ?', time_range.first, time_range.last)
      end
      
      ##
      #Finds all jobs that were running at some point in a given time range
      def self.by_time_range(time_range)
        if time_range.empty?
          self.none
        elsif time_range.exclude_end?
          where('? <= jobs.end_time AND jobs.start_time < ?', time_range.first, time_range.last)
        else
          where('? <= jobs.end_time AND jobs.start_time <= ?', time_range.first, time_range.last)
        end
      end

      ##
      #Similar to #by_time_range, but only includes jobs that are completely contained within the
      #time range
      def self.within_time_range(time_range)
        if time_range.empty?
          self.none
        elsif time_range.exclude_end?
          where('? <= jobs.start_time AND jobs.end_time < ?', time_range.first, time_range.last)
        else
          where('? <= jobs.start_time AND jobs.end_time <= ?', time_range.first, time_range.last)
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
      #TODO: filter out jobs with 0 CPU time?
      def self.summary(time_range = nil)
        jobs = self

        num_jobs = 0
        successful = 0
        cpu_time = 0
        memory_time = 0

        if time_range
          time_range = time_range.normalized
          jobs = jobs.by_time_range(time_range)

          jobs.each do |job|
            job_start_time = job.start_time
            job_end_time = job.end_time
            job_start_time = [job_start_time, time_range.first].max
            job_end_time = [job_end_time, time_range.last].min
            clipped_wall_time = job_end_time.to_i - job_start_time.to_i
            if job.wall_time != 0
              cpu_time += job.cpu_time * clipped_wall_time / job.wall_time
              #To consider: what should I do about jobs that only report a max memory value?
              memory_time += job.memory * clipped_wall_time
            end
            successful += 1 if job.exit_code == 0
          end
          num_jobs = jobs.count
          successful = jobs.where(:exit_code => 0).count
        else
          num_jobs = jobs.count
          successful = jobs.where(:exit_code => 0).count
          cpu_time = jobs.sum(:cpu_time)
          memory_time = jobs.sum('jobs.memory * jobs.wall_time')
        end

        return {
          :num_jobs => num_jobs,
          :successful => successful,
          :cpu_time => cpu_time,
          :memory_time => memory_time,
        }
      end
      
      ##
      #Returns an array of all jobs, pre-loading relations to reduce the need for extra queries
      #
      #Relations are not cached between calls.
      #
      #To do: use ActiveRecord's #includes instead of this scheme?
      def self.all_with_relations
        jobs = self.where(nil).to_a
        users = {}
        groups = {}
        systems = {}
        system_types = {}
        jobs.each do |job|
          system = systems[job.system_id]
          if system
            job.system = system
          else
            system = job.system
            systems[system.id] = system
          end
          system_type = system_types[system.system_type_id]
          if system_type
            system.system_type = system_type
          else
            system_type = system.system_type
            system_types[system_type.id] = system_type
          end
          user = users[job.user_id]
          if user
            job.user = user
          else
            user = job.user
            users[user.id] = user
          end
          group = groups[user.group_id]
          if group
            user.group = group
          else
            group = user.group
            groups[group.id] = group
          end
        end
        
        jobs
      end
      
      before_save do
        write_attribute(:end_time, end_time)
      end
      
      before_update do
        write_attribute(:end_time, end_time)
      end
      
      validates_presence_of :user, :system, :cpu_time,
        :start_time, :wall_time, :memory, :exit_code
        
      validates_each :command_name do |record, attr, value|
        record.errors.add(attr, 'must not be nil') if value == nil
      end
       
      validates_each :cpu_time, :wall_time, :memory do |record, attr, value|
        record.errors.add(attr, 'must be a non-negative integer') unless value && value >= 0
      end
    end
  end
end
