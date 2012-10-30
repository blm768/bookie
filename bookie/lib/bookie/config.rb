require 'bookie'

require 'active_record'
require 'json'
require 'set'

module Bookie
  #Holds database configuration, etc. for Bookie components
  #
  #==Configuration format
  #The configuration file is a JSON file with the following fields:
  #* "Database type": the type of database to be used
  #  - Defaults to "mysql2"
  #  - Corresponds to ActiveRecord database adapter name
  #* "Server": the hostname of the server (required)
  #* "Port": the port on which to connect to the server (optional)
  #* "Database": the name of the database to use
  #  - Defaults to "bookie"
  #* "Username": the username for the database
  #  - Defaults to "root"
  #* "Password": the password for the database
  #  - Defaults to ""
  #* "Excluded users": an array of usernames to be excluded from the database (optional)
  #* "System type": The type of system
  #  - "Standalone": a standalone machine
  #  - "TORQUE cluster": the head of a TORQUE cluster
  #  - Defaults to "Standalone"
  #* "Hostname": the system's hostname (required)
  class Config
    #The database type
    #
    #Corresponds to ActiveRecord database adapter name
    attr_accessor :db_type
    #The database server's hostname
    attr_accessor :server
    #The database server's port
    #
    #If nil, use the default port.
    attr_accessor :port
    #The name of the database to use
    attr_accessor :database
    #The username for the database
    attr_accessor :username
    #The password for the database
    attr_accessor :password
    #A set containing the names of users to be excluded
    attr_accessor :excluded_users
    #The system type
    attr_accessor :system_type
    #The system's hostname
    attr_accessor :hostname
    #The directory in which to place old logs
    attr_accessor :log_dir
    
    #==Parameters
    #* filename: the name of the JSON file from which to load the configuration settings
    def initialize(filename)
      file = File.open(filename)
      data = JSON::parse(file.read)
      file.close
      
      @db_type = data['Database type'] || 'mysql2'
      verify_type(@db_type, 'Database type', String)
      
      @server = data['Server']
      raise "No database server specified" unless @server
      verify_type(@server, 'Server', String)
      @port = data['Port']
      verify_type(@port, 'Port', Fixnum) unless @port == nil
      
      @database = data['Database'] || "bookie"
      verify_type(@database, 'Database', String)
      @username = data['Username'] || "root"
      verify_type(@username, 'Username', String)
      @password = data['Password'] || ""
      verify_type(@password, 'Password', String)
      
      excluded_users_array = data['Excluded users'] || []
      verify_type(excluded_users_array, 'Excluded users', Array)
      @excluded_users = Set.new(excluded_users_array)
      
      #To do: unit tests
      @system_type = data['System type'] || "Standalone"
      verify_type(@system_type, 'System type', String)
      
      @hostname = data['Hostname']
      raise "No hostname specified" unless @hostname
      verify_type(@hostname, 'Hostname', String)
      
      @log_dir = data['LogDir']
      verify_type(@log_dir, 'LogDir', String)
    end
    
    #Verifies that a field is of the correct type, raising an error if the type does not match
    def verify_type(value, name, type)
      raise TypeError.new("Invalid data type #{value.class} for JSON field \"#{name}\": #{type} expected") unless value.class == type
    end
    
    #Connects to the database specified in the configuration file
    def connect()
      #To do: this is deprecated; find alternative?
      #ActiveRecord.colorize_logging = false
      #To do: create config option for this?
      #ActiveRecord::Base.logger = Logger.new(STDERR)
      ActiveRecord::Base.establish_connection(
        :adapter  => self.db_type,
        :database => self.database,
        :username => self.username,
        :password => self.password,
        :host     => self.server,
        :port     => self.port)
    end
  end
end