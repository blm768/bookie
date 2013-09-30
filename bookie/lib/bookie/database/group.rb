require 'active_record'

require 'bookie/database/lock.rb'

module Bookie
  module Database
    ##
    #A group of users
    class Group < ActiveRecord::Base
      has_many :users

      ##
      #Finds a group by name, creating it if it doesn't exist
      #
      #If <tt>known_groups</tt> is provided, it will be used as a cache to reduce the number of database lookups needed.
      #
      #This uses Lock#synchronize internally, so it probably should not be called within a transaction block.
      def self.find_or_create!(name, known_groups = nil)
        group = known_groups[name] if known_groups
        unless group
          Lock[:groups].synchronize do
            group = find_by_name(name)
            group ||= create!(:name => name)
          end
          known_groups[name] = group if known_groups
        end
        group
      end
      
      validates_presence_of :name
    end
  end
end
