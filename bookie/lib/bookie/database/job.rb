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
      #TODO: include group and system_type with a :through association?
      
      ##
      #The time at which the job ended
      def end_time
        return start_time + wall_time
      end

      #TODO: unit test.
      def end_time=(time)
        self.wall_time = (time - start_time)
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
      #Finds all jobs that overlap the edges of the given time range
      def self.overlapping_edges(time_range)
        if time_range.empty?
          self.none
        else
          time_range = time_range.exclusive
          query_str = ['begin', 'end'].map{ |edge| "(jobs.start_time < :#{edge} AND jobs.end_time > :#{edge})" }.join(" OR ")
          where(query_str, {:begin => time_range.begin, :end => time_range.end})
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
      #The time_range parameter is always treated as if time_range.exclude_end? is true.
      def self.summary(time_range = nil)
        jobs = self

        num_jobs = 0
        successful = 0
        cpu_time = 0
        memory_time = 0

        if time_range
          unless time_range.empty?
            time_range = time_range.exclusive

            #Any jobs that are completely within the time range can
            #be summarized as-is.
            jobs_within = jobs.within_time_range(time_range)
            #TODO: optimize into one query?
            num_jobs += jobs_within.count
            successful += jobs_within.where(:exit_code => 0).count
            cpu_time += jobs_within.sum(:cpu_time)
            memory_time += jobs_within.sum('jobs.memory * jobs.wall_time')

            #Any jobs that overlap an edge of the time range
            #must be clipped.
            jobs_overlapped = jobs.overlapping_edges(time_range)
            jobs_overlapped.each do |job|
              start_time = [job.start_time, time_range.begin].max
              end_time = [job.end_time, time_range.end].min
              clipped_wall_time = end_time.to_i - start_time.to_i
              if job.wall_time != 0
                #TODO: switch to floating-point arithmetic?
                cpu_time += job.cpu_time * clipped_wall_time / job.wall_time
                memory_time += job.memory * clipped_wall_time
              end
              num_jobs += 1
              successful += 1 if job.exit_code == 0
            end
          end
        else
          #There's no time_range constraint; just summarize everything.
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
      #Returns an array of all jobs, pre-loading associations to reduce the need for extra queries
      #
      #Relations are not cached between calls.
      #
      #TODO: use ActiveRecord's #includes instead of this scheme?
      def self.all_with_associations
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
