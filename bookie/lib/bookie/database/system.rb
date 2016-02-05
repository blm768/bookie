require 'active_record'

require 'bookie/database/lock.rb'
require 'bookie/database/system_type.rb'

module Bookie
  module Database
    ##
    #A system on the network
    class System < ActiveRecord::Base
      ##
      #Raised when a system's specifications are different from those of the active system in the database
      SystemConflictError = Class.new(RuntimeError)

      has_many :jobs
      belongs_to :system_type

      ##
      #Finds all systems that are active (i.e. all systems with NULL values for end_time)
      def self.active
        where('systems.end_time IS NULL')
      end

      ##
      #Filters by name
      def self.by_name(name)
        where('systems.name = ?', name)
      end

      ##
      #Filters by system type
      def self.by_system_type(sys_type)
        where('systems.system_type_id = ?', sys_type.id)
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
      #Finds the current system for a given sender and time
      #
      #This method also checks that this system's specifications in the local configuration are the same as those in
      #the database and raises an error if they are different.
      #
      #TODO: don't do the above?
      #
      #TODO: decouple from Sender class.
      def self.find_current(sender, time = nil)
        time ||= Time.now
        config = sender.config

        system = by_name(config.hostname).where('systems.start_time <= :time AND (:time <= systems.end_time OR systems.end_time IS NULL)', :time => time).first
        if system
          mismatch = (system.cores != config.cores) || (system.memory != config.memory)
          #Note that this uses the Sender's field, not the config's. They're different types.
          mismatch ||= sender.system_type != system.system_type
          if mismatch then
            raise SystemConflictError.new("The specifications on record for '#{name}' do not match this system's specifications.
Please make sure that all previous systems with this hostname have been marked as decommissioned.")
          end
        else
          #TODO: use find! instead of where() and let the caller prettify the message?
          raise "There is no system with hostname '#{config.hostname}' that was recorded as active at #{time}."
        end

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

      ##
      #Decommissions the given system, setting its end time to <tt>end_time</tt>
      #
      #This should be called any time a system is brought down or its specifications are changed.
      def decommission(end_time)
        self.end_time = end_time
        self.save!
      end

      validates_presence_of :name, :cores, :memory, :system_type, :start_time

      validates_each :cores, :memory do |record, attr, value|
        record.errors.add(attr, 'must be a non-negative integer') unless value && value >= 0
      end

      validates_each :end_time do |record, attr, value|
        record.errors.add(attr, 'must be at or after start time') if value && value < record.start_time
      end
    end

  end
end
