require 'bookie'

require 'active_record'
require 'json'
require 'logger'
require 'set'
require 'system_stats'

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
    
    #The system type
    def system_type
      raise "No system type specified" unless @system_type
      @system_type
    end
    
    #The number of cores on the system
    def cores
      @cores ||= @stats.num_cores
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
      
      @stats = SystemStats::LocalStats.new
      
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
      @system_type = data['System type']
      verify_type(@system_type, 'System type', String) unless @system_type == nil
      
      @hostname = data['Hostname']
      raise "No hostname specified" unless @hostname
      verify_type(@hostname, 'Hostname', String)
      
      @maximum_idle = data['Maximum idle time'] || 3
      verify_type(@maximum_idle, 'Maximum idle time', Integer)
    end
    
    #If called, this should be called before passing the object to anything else.
    def parse_options(opts)
      opts.on('-h', '--hostname HOSTNAME', 'Set hostname under which to record jobs') do |hostname|
        @hostname = hostname
      end
      
      opts.on('-c', '--cores CORES', Integer, 'Specify number of cores in the system') do |cores|
        @cores = cores
      end
      
      opts.on('-m', '--memory KB', Integer, "Specify system's RAM (in KB)") do |memory|
        @memory = memory
      end
      
      opts.on('-t', '--log-type TYPE', 'Specify log type') do |log_type|
        @system_type = log_type
      end
    end
    
    #Verifies that a field is of the correct type, raising an error if the type does not match
    def verify_type(value, name, type)
      raise TypeError.new("Invalid data type #{value.class} for JSON field \"#{name}\": #{type} expected") unless value.class <= type
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