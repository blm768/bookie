require 'active_record'

require 'bookie/database/lock.rb'
require 'bookie/database/group.rb'

module Bookie
  module Database
    ##
    #Model for a user
    class User < ActiveRecord::Base
      #ID must be specified before saving because it's supposed to have an actual UNIX UID.
      #TODO: find a cleaner way to handle this? (i.e. no default value for the primary key on the database side)
      validates_presence_of :name, :id

      def self.by_name(name)
        where('users.name = ?', name)
      end

      ##
      #Finds a user by id, creating it if it doesn't exist
      #
      #If <tt>known_users</tt> is provided, it will be used as a cache to reduce the number of database lookups needed.
      #TODO: use first_or_create instead.
      def self.find_or_create!(id, name, known_users = nil)
        #Determine if the user must be added to/retrieved from the database.
        user = known_users[id] if known_users
        return user if user

        #Does the user already exist?
        user = Bookie::Database::User.find(id)
        user ||= Bookie::Database::User.create!(id: id, name: name)
        known_users[name] = user if known_users

        user
      end
    end
  end
end
