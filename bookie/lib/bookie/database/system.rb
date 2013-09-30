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
      def self.active_systems
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
      #
      #TODO: unit test.
      def self.by_time_range_inclusive(time_range)
        if time_range.empty?
          self.none
        elsif time_range.exclude_end?
          where('(? <= systems.end_time OR systems.end_time IS NULL) AND systems.start_time < ?', time_range.first, time_range.last)
        else
          where('(? <= systems.end_time OR systems.end_time IS NULL) AND systems.start_time <= ?', time_range.first, time_range.last)
        end
      end

      ##
      #Finds the current system for a given sender and time
      #
      #This method also checks that this system's specifications are the same as those in the database and raises an error if they are different.
      #
      #This uses Lock#synchronize internally, so it probably should not be called within a transaction block.
      def self.find_current(sender, time = nil)
        time ||= Time.now
        config = sender.config
        system = nil
        name = config.hostname
        Lock[:systems].synchronize do
          system = by_name(config.hostname).where('systems.start_time <= :time AND (:time <= systems.end_time OR systems.end_time IS NULL)', :time => time).first
          if system
            mismatch = !(system.cores == config.cores && system.memory == config.memory)
            mismatch ||= sender.system_type != system.system_type
            if mismatch
              raise SystemConflictError.new("The specifications on record for '#{name}' do not match this system's specifications.
Please make sure that all previous systems with this hostname have been marked as decommissioned.")
            end
          else
            raise "There is no system with hostname '#{config.hostname}' that was recorded as active at #{time}."
          end
        end
        system
      end
      
      ##
      #Returns an array of all systems, pre-loading relations to reduce the need for extra queries
      #
      #Relations are not cached between calls.
      def self.all_with_relations
        systems = self.where(nil).to_a
        system_types = {}
        systems.each do |system|
          system_type = system_types[system.system_type_id]
          if system_type
            system.system_type = system_type
          else
            system_type = system.system_type
            system_types[system_type.id] = system_type
          end
        end
        systems
      end
 
      ##
      #Produces a summary of all the systems for the given time interval
      #
      #Returns a hash with the following fields:
      #- [<tt>:systems</tt>] an array containing all systems that are active in the interval
      #- [<tt>:avail_cpu_time</tt>] the total CPU time available for the interval
      #- [<tt>:avail_memory_time</tt>] the total amount of memory-time available (in kilobyte-seconds)
      #- [<tt>:avail_memory_avg</tt>] the average amount of memory available (in kilobytes)
      #
      #To consider: include the start/end times for the summary (especially if they aren't provided as arguments)?
      #
      #Notes:
      #
      #Results may be slightly off when an inclusive range is used.
      #To consider: is this worth fixing?
      def self.summary(time_range = nil)
        #To consider: how to handle time zones with Rails apps?
        current_time = Time.now
        #Sums that are actually returned
        avail_cpu_time = 0
        avail_memory_time = 0
        #Find all the systems within the time range.
        systems = System
        if time_range
          time_range = time_range.normalized
          #TODO: unit test.
          systems = systems.by_time_range_inclusive(time_range)
        end

        all_systems = systems.all_with_relations
        
        all_systems.each do |system|
          system_start_time = system.start_time
          system_end_time = system.end_time
          #Is there a time range constraint?
          if time_range
            system_start_time = [system_start_time, time_range.first].max
            system_end_time = [system_end_time, time_range.last].min if system.end_time
            system_end_time ||= time_range.last
          else
            system_end_time ||= current_time
          end
          system_wall_time = system_end_time.to_i - system_start_time.to_i
          avail_cpu_time += system.cores * system_wall_time
          avail_memory_time += system.memory * system_wall_time
        end
        
        wall_time_range = 0
        if time_range
          wall_time_range = time_range.last - time_range.first
        else
          first_started_system = systems.order(:start_time).first
          if first_started_system
            #Is there a system still active?
            last_ended_system = systems.where('systems.end_time IS NULL').first
            if last_ended_system
              wall_time_range = current_time.to_i - first_started_system.start_time.to_i
            else
              #No; find the system that was brought down last.
              last_ended_system = systems.order('end_time DESC').first
              wall_time_range = last_ended_system.end_time.to_i - first_started_system.start_time.to_i
            end
          end
        end
          
        {
          :systems => all_systems,
          :avail_cpu_time => avail_cpu_time,
          :avail_memory_time => avail_memory_time,
          :avail_memory_avg => if wall_time_range == 0 then 0.0 else Float(avail_memory_time) / wall_time_range end,
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
