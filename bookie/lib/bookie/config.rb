require 'bookie'

require 'json'

module Bookie
  #Holds database configuration, etc. for Bookie components
  class Config
    #The database server's hostname
    attr_accessor :server
    #The database server's port
    #
    #If nil, use the default port.
    attr_accessor :port
    #The username for the database
    #
    #Defaults to "root"
    attr_accessor :username
    #The password for the database
    #
    #Defaults to ""
    attr_accessor :password
    #A set containing the names of users to be excluded
    #
    #Defaults to an empty set
    attr_accessor :excluded_users
    
    #==Parameters
    #* filename: the name of the JSON file from which to load the configuration settings
    def initialize(filename)
      file = File.open(filename)
      data = JSON::parse(file.read)
      file.close
      
      @server = data['Server']
      raise "No database server specified" unless @server
      verify_type(@server, 'Server', String)
      @port = data['Port']
      verify_type(@port, 'Port', Fixnum) unless @port == nil
      
      @username = data['Username'] || "root"
      verify_type(@username, 'Username', String)
      @password = data['Password'] || ""
      verify_type(@password, 'Password', String)
      
      excluded_users_array = data['Excluded users'] || []
      verify_type(excluded_users_array, 'Excluded users', Array)
      @excluded_users = Set.new(excluded_users_array)
    end
    
    #Verifies that a field is of the correct type, raising an error if the type does not match
    def verify_type(value, name, type)
      raise TypeError.new("Invalid data type #{value.class} for JSON field \"#{name}\": #{type} expected") unless value.class == type
    end
  end
end