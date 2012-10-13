require 'bookie'

require 'json'

module Bookie
  #Holds database configuration, etc. for Bookie components
  #
  #==Configuration format
  #The configuration file is a JSON file with the following fields:
  #* "Database type": the type of database to be used
  #  - Defaults to "mysql"
  #  - Corresponds to ActiveRecord database adapter name
  #* "Server": the hostname of the server (mandatory)
  #* "Port": the port on which to connect to the server (optional)
  #* "Username": the username for the database
  #  - Defaults to "root"
  #* "Password": the password for the database
  #  - Defaults to ""
  #* "Excluded users": an array of usernames to be excluded from the database (optional)
  class Config
    #The database type
    #
    #Corresponds to ActiveRecord database adapter name; defaults to 'mysql'
    attr_accessor :db_type
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
      
      @db_type = data['Database type'] || 'mysql'
      verify_type(@db_type, 'Database type', String)
      
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