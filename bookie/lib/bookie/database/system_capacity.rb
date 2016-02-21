require 'active_record'

require 'bookie/database/system'

module Bookie::Database
  ##
  #Represents the capacity of a system (i.e. its memory and number of CPU cores)
  class SystemCapacity < ActiveRecord::Base
    belongs_to :system

    #TODO: unit test.
    validates :system, presence: true
    validates :cores, :memory, numericality: { greater_than_or_equal_to: 0 }
    validates :start_time, presence: true

    #TODO: validate that this time range does not cover any other capacity's range for this system.
    #TODO: validate that only one entry per system is "current".
    validates_each :end_time do |record, attr, value|
      record.errors.add(attr, 'must be at or after start time') if value && value < record.start_time
    end

    #TODO: doc and unit test.
    #TODO: remove?
    def self.current
      self.where(end_time: nil)
    end

    ##
    #Finds all SystemCapacity records overlapping the given time range
    #
    #time_min and/or time_max may be nil, which represents infinity.
    def self.by_time_range(time_min, time_max)
      return self.none if time_min && time_max && time_max <= time_min

      capacities = self

      if time_min then
        capacities = capacities.where(
          '? < system_capacities.end_time OR system_capacities.end_time IS NULL',
          time_min
        )
      end
      if time_max then
        capacities = capacities.where('? > system_capacities.start_time', time_max)
      end

      capacities
    end

    ##
    #Produces a summary of the total system capacity for the given time interval
    #
    #Returns a hash with the following fields:
    #- [<tt>:num_systems</tt>] the number of systems that were available in the given interval
    #- [<tt>:avail_cpu_time</tt>] the total CPU time available for the interval
    #- [<tt>:avail_memory_time</tt>] the total amount of memory-time available (in kilobyte-seconds)
    #- [<tt>:avail_memory_avg</tt>] the average amount of memory available (in kilobytes)
    #
    #TODO: include the start/end times for the summary (especially if they aren't provided as arguments)?
    #TODO: use those in combined summary stuff.
    def self.summary(time_min, time_max)
      current_time = Time.now

      system_ids = Set.new
      avail_cpu_time = 0
      avail_memory_time = 0

      #Find all the SystemCapacities within the time range.
      capacities = self
      capacities = capacities.by_time_range(time_min, time_max)

      capacities.find_each do |capacity|
        start_time = capacity.start_time
        end_time = capacity.end_time || current_time
        #Trim start_time and end_time to fit within the range.
        start_time = [start_time, time_min].max if time_min
        end_time = [end_time, time_max].min if time_max

        wall_time = end_time.to_i - start_time.to_i

        system_ids.add(capacity.system_id)
        avail_cpu_time += capacity.cores * wall_time
        avail_memory_time += capacity.memory * wall_time
      end

      #If time_min or time_max wasn't provided, find a reasonable value.
      #TODO: re-think this logic?
      time_min ||= self.minimum(:start_time)
      unless time_max
        if self.current.any?
          time_max = current_time
        else
          time_max = self.maximum(:end_time)
        end
      end

      time_span = 0
      #Is there actually a minimum start time?
      #(In other words, are there any system capacity entries in the database?)
      if time_min
        time_span = time_max - time_min
      end

      #TODO: replace avail_memory_avg with time_span and/or a time range?
      {
        :num_systems => system_ids.length,
        :avail_cpu_time => avail_cpu_time,
        :avail_memory_time => avail_memory_time,
        :avail_memory_avg => if time_span == 0 then 0.0 else Float(avail_memory_time) / time_span end,
      }
    end
  end
end
