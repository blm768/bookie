require 'bookie'

require 'active_record'
require 'json'
require 'logger'
require 'set'

module Bookie
  #Holds database configuration, etc. for Bookie components
  #
  #==Configuration format (To do: update!)
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
  #  - Other values are possible depending on which sender plugins are installed.
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
    #The system's hostname
    attr_accessor :hostname
    #The number of days a system can fail to post job entries before a warning is made
    attr_accessor :maximum_idle
    #The number of cores on the system
    attr_accessor :cores
    
    #The system type
    def system_type
      raise "No system type specified" unless @system_type
      @system_type
    end
    
    
    #The RAM (in KB) in the system
    def memory
      @memory ||= @stats.memory[:total]
    end
       
    #==Parameters
    #* filename: the name of the JSON file from which to load the configuration settings
    def initialize(filename)
      file = File.open(filename)
      data = JSON::parse(file.read)
      file.close
      
      @db_type = data['Database type']
      raise 'No database type specified' unless @db_type
      verify_type(@db_type, 'Database type', String)
      
      @server = data['Server']
      raise "No database server specified" unless @server
      verify_type(@server, 'Server', String)
      @port = data['Port']
      verify_type(@port, 'Port', Integer) unless @port == nil
      
      @database = data['Database']
      raise 'No database specified' unless @database
      verify_type(@database, 'Database', String)
      @username = data['Username']
      raise 'No database username specified' unless @database
      verify_type(@username, 'Username', String)
      @password = data['Password']
      raise 'No database password specified' unless @password
      verify_type(@password, 'Password', String)
      
      excluded_users_array = data['Excluded users'] || []
      verify_type(excluded_users_array, 'Excluded users', Array)
      @excluded_users = Set.new(excluded_users_array)
      
      @system_type = data['System type']
      raise 'No system type specified' unless @system_type
      verify_type(@system_type, 'System type', String)
      
      @hostname = data['Hostname']
      raise "No hostname specified" unless @hostname
      verify_type(@hostname, 'Hostname', String)
      
      @cores = data['Cores']
      raise 'Number of cores not specified' unless @cores
      verify_type(@cores, 'Cores', Integer)
      
      @memory = data['Memory']
      raise 'Memory not specified' unless @memory
      verify_type(@memory, 'Memory', Integer)
      
      @maximum_idle = data['Maximum idle time'] || 3
      verify_type(@maximum_idle, 'Maximum idle time', Integer)
    end
    
    #Verifies that a field is of the correct type, raising an error if the type does not match
    def verify_type(value, name, type)
      raise TypeError.new("Invalid data type #{value.class} for JSON field \"#{name}\": #{type} expected") unless value.class <= type
    end
    
    #Connects to the database specified in the configuration file
    def connect()
      #To consider: disable colorized logging?
      #To consider: create config option for this?
      #ActiveRecord::Base.logger = Logger.new(STDERR)
      #ActiveRecord::Base.logger.level = Logger::WARN
      ActiveRecord::Base.time_zone_aware_attributes = true
      ActiveRecord::Base.default_timezone = :utc
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
