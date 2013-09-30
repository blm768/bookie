require 'active_record'

require 'bookie/database/lock.rb'
require 'bookie/database/group.rb'

module Bookie
  module Database
    ##
    #Model for a user
    class User < ActiveRecord::Base
      belongs_to :group
      
      def self.by_name(name)
        where('users.name = ?', name)
      end

      def self.by_group(group)
        return where('users.group_id = ?', group.id)
      end

      def self.by_group_name(name)
        group = Group.find_by_name(name)
        return by_group(group) if group
        self.none
      end
      
      ##
      #Finds a user by name and group, creating it if it doesn't exist
      #
      #If <tt>known_users</tt> is provided, it will be used as a cache to reduce the number of database lookups needed.
      #
      #This uses Lock#synchronize internally, so it probably should not be called within a transaction block.
      def self.find_or_create!(name, group, known_users = nil)
        #Determine if the user/group pair must be added to/retrieved from the database.
        user = known_users[[name, group]] if known_users
        unless user
          Lock[:users].synchronize do
            #Does the user already exist?
            user = Bookie::Database::User.find_by_name_and_group_id(name, group.id)
            user ||= Bookie::Database::User.create!(
              :name => name,
              :group => group
            )
          end
          known_users[[name, group]] = user if known_users
        end
        user
      end
      
      validates_presence_of :group, :name
    end

  end
end
