require 'active_record'

require 'bookie/database/lock.rb'
require 'bookie/database/group.rb'

module Bookie
  module Database
    ##
    #Model for a user
    class User < ActiveRecord::Base
      def self.by_name(name)
        where('users.name = ?', name)
      end

      ##
      #Finds a user by name and group, creating it if it doesn't exist
      #
      #If <tt>known_users</tt> is provided, it will be used as a cache to reduce the number of database lookups needed.
      def self.find_or_create!(name, known_users = nil)
        #Determine if the user must be added to/retrieved from the database.
        user = known_users[name] if known_users
        return user if user

        #Does the user already exist?
        user = Bookie::Database::User.find_by(name: name)
        user ||= Bookie::Database::User.create!(name: name)
        known_users[name] = user if known_users

        user
      end

      validates_presence_of :name
    end

  end
end
