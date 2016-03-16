require 'bookie/database'

module Bookie::Database
  ##
  #Model for a user
  class User < Model
    #ID must be specified before saving because it's supposed to have an actual UNIX UID.
    #TODO: find a cleaner way to handle this? (i.e. no default value for the primary key on the database side)
    validates_presence_of :name, :id
  end
end
