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
        joins(:system_capacities).where('end_time IS NULL')
      end

      ##
      #Finds a system by name, creating it if it doesn't exist
      #
      #If the Hash <tt>known_systems</tt> is provided, it will be used as a cache to reduce the number of database lookups needed.
      def self.find_or_create!(name, system_type, known_systems = nil)
        #Determine if the system must be added to/retrieved from the database.
        system = known_systems[name] if known_systems
        return system if system

        system = Bookie::Database::System.find_by(name: name)
        system ||= Bookie::Database::System.create!(name: name, system_type: system_type)
        known_systems[name] = system if known_systems

        system
      end

      #TODO: doc and test if used.
      #TODO: put a "current" method on the system_capacities relation instead?
      def current_capacity
        SystemCapacity.where(system_id: self.id).order('start_time DESC').first
      end

      ##
      #Returns whether this system is "active" (i.e. it has a current capacity entry)
      #
      #TODO: rename? Allow providing a time range?
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
