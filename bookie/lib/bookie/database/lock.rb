require 'active_record'

module Bookie
  module Database
    ##
    #Simulates table locks on databases that only have row locks
    #
    #Based on http://kseebaldt.blogspot.com/2007/11/synchronizing-using-active-record.html
    #
    #This should probably not be called within a transaction block. The transaction that
    #this method creates uses the option :requires_new => true, limiting the negative effects
    #of nested transactions, but concurrency safety is still strongly dependent on how the
    #database engine handles locks.
    class Lock < ActiveRecord::Base
      ##
      #Acquires the lock, runs the given block, and releases the lock when finished
      def synchronize
        transaction(:requires_new => true) do
          #Lock this record to be inaccessible to others until this transaction is completed.
          self.class.lock.find(id)
          yield
        end
      end

      @locks = {}

      ##
      #Returns a lock by name
      def self.[](name)
        @locks[name.to_sym] ||= find_by!(name: name.to_s)
      end

      validates_presence_of :name
    end
  end
end
