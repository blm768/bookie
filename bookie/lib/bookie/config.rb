require 'bookie'

require 'active_record'
require 'json'
require 'logger'
require 'set'

module Bookie
  ##
  #Holds database configuration, etc. for Bookie components
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
    #The number of cores on the system
    attr_accessor :cores
    #The RAM (in KB) in the system
    attr_accessor :memory
       
    ##
    #Creates a new Config object using values from the provided JSON file
    def initialize(filename)
      file = File.open(filename)
      data = JSON::parse(file.read)
      file.close
      
      @db_type = data['Database type']
      verify_type(@db_type, 'Database type', String)
      
      @server = data['Server']
      verify_type(@server, 'Server', String)
      @port = data['Port']
      verify_type(@port, 'Port', Integer) unless @port == nil
      
      @database = data['Database']
      verify_type(@database, 'Database', String)
      @username = data['Username']
      verify_type(@username, 'Username', String)
      @password = data['Password']
      verify_type(@password, 'Password', String)
      
      excluded_users_array = data['Excluded users'] || []
      verify_type(excluded_users_array, 'Excluded users', Array)
      @excluded_users = Set.new(excluded_users_array)
      
      @system_type = data['System type']
      verify_type(@system_type, 'System type', String)
      
      @hostname = data['Hostname']
      verify_type(@hostname, 'Hostname', String)
      
      @cores = data['Cores']
      verify_type(@cores, 'Cores', Integer)
      
      @memory = data['Memory']
      verify_type(@memory, 'Memory', Integer)
    end
    
    #Verifies that a field is of the correct type, raising an error if the type does not match
    def verify_type(value, name, type)
      if value == nil
        raise "Field \"#{name}\" must have a non-null value."
      end
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
