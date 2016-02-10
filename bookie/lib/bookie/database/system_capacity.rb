require 'active_record'

require 'bookie/database/system'

module Bookie
  module Database
    ##
    #Represents the capacity of a system (i.e. its memory and number of CPU cores)
    class SystemCapacity < ActiveRecord::Base
      belongs_to :system

      #TODO: unit test.
      validates :system, presence: true
      validates :cores, :memory, numericality: { greater_than_or_equal_to: 0 }
      validates :start_time, presence: true

      #TODO: validate that this time range does not cover any other capacity's range for this system.
      validates_each :end_time do |record, attr, value|
        record.errors.add(attr, 'must be at or after start time') if value && value < record.start_time
      end
    end
  end
end
