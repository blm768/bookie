require 'active_record'

require 'bookie/database/lock.rb'
require 'bookie/database/group.rb'

module Bookie::Database
  ##
  #Model for a user
  class User < ActiveRecord::Base
    #ID must be specified before saving because it's supposed to have an actual UNIX UID.
    #TODO: find a cleaner way to handle this? (i.e. no default value for the primary key on the database side)
    validates_presence_of :name, :id
  end
end
