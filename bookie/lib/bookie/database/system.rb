require 'active_record'

require 'bookie/database/lock.rb'
require 'bookie/database/system_type.rb'

module Bookie
  module Database
    ##
    #A system on the network
    #
    #TODO: support changing a system's type? (...or remove it entirely...)
    class System < ActiveRecord::Base
      has_many :jobs
      has_many :system_capacities
      belongs_to :system_type

      ##
      #Finds all systems that are active (i.e. all systems with NULL values
      #for the end_time of their last capacity entry)
      def self.active
        joins(:system_capacity).where('end_time IS NULL')
      end

      ##
      #Finds all systems whose running intervals overlap the given time range
      def self.by_time_range(time_range)
        if time_range.empty?
          self.none
        else
          time_range = time_range.exclusive
          where('(? < systems.end_time OR systems.end_time IS NULL) AND systems.start_time < ?', time_range.first, time_range.last)
        end
      end

      ##
      #Finds a system by hostname, creating it if it doesn't exist
      #
      #If <tt>known_systems</tt> is provided, it will be used as a cache to reduce the number of database lookups needed.
      def self.find_or_create!(hostname, system_type, known_systems = nil)
        #Determine if the system must be added to/retrieved from the database.
        system = known_systems[hostname] if known_systems
        return system if system

        system = Bookie::Database::System.find(hostname)
        user ||= Bookie::Database::User.create!(hostname: hostname, system_type: system_type)
        known_systems[hostname] = system if known_systems

        system
      end

      ##
      #Produces a summary of all the systems for the given time interval
      #
      #Returns a hash with the following fields:
      #- [<tt>:num_systems</tt>] the number of systems that were active in the given interval
      #- [<tt>:avail_cpu_time</tt>] the total CPU time available for the interval
      #- [<tt>:avail_memory_time</tt>] the total amount of memory-time available (in kilobyte-seconds)
      #- [<tt>:avail_memory_avg</tt>] the average amount of memory available (in kilobytes)
      #
      #To consider: include the start/end times for the summary (especially if they aren't provided as arguments)?
      def self.summary(time_range = nil)
        current_time = Time.now

        num_systems = 0
        avail_cpu_time = 0
        avail_memory_time = 0

        #Find all the systems within the time range.
        systems = System
        if time_range
          time_range = time_range.exclusive.normalized
          systems = systems.by_time_range(time_range)
        end

        systems.find_each do |system|
          start_time = system.start_time
          end_time = system.end_time
          #Is there a time range constraint?
          if time_range
            #If so, trim start_time and end_time to fit within the range.
            start_time = [start_time, time_range.first].max
            if end_time
              end_time = [end_time, time_range.last].min
            else
              end_time ||= time_range.last
            end
          else
            end_time ||= current_time
          end
          wall_time = end_time.to_i - start_time.to_i

          num_systems += 1
          avail_cpu_time += system.cores * wall_time
          avail_memory_time += system.memory * wall_time
        end

        time_span = 0
        if time_range
          time_span = time_range.last - time_range.first
        else
          time_min = System.minimum(:start_time)
          #Is there actually a minimum start time?
          #(In other words, are there any systems in the database?)
          if time_min
            if System.active.any?
              time_max = current_time
            else
              time_max = System.maximum(:end_time)
            end
            time_span = time_max - time_min
          end
        end

        {
          :num_systems => num_systems,
          :avail_cpu_time => avail_cpu_time,
          :avail_memory_time => avail_memory_time,
          :avail_memory_avg => if time_span == 0 then 0.0 else Float(avail_memory_time) / time_span end,
        }
      end

      #TODO: doc and test if used.
      def current_capacity
        SystemCapacity.where(system_id: self.id).order('start_time DESC').first
      end

      ##
      #Returns whether this system is "active" (i.e. it has a current capacity entry)
      def active?
        cap = current_capacity
        if cap then cap.end_time == nil else false end
      end

      ##
      #Marks this system as decommissioned
      def decommission!(end_time)
        cap = current_capacity
        return unless cap
        cap.end_time = end_time
        cap.save!
      end

      validates_presence_of :name, :system_type
    end
  end
end
