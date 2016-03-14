require 'bookie/config'
require 'bookie/extensions'

require 'active_record'

require 'bookie/database/job'
require 'bookie/database/job_summary'
require 'bookie/database/system'
require 'bookie/database/system_type'
require 'bookie/database/system_capacity'
require 'bookie/database/user'

module Bookie
  ##
  #Contains database-related code and models
  module Database
    ##
    #Location of database migrations
    MIGRATIONS_PATH = File.expand_path('./database/migrations/', File.dirname(__FILE__))
    class << self;
      ##
      #Finds the latest database version (the highest migration version)
      def latest_version
        max_version = 0
        Dir.entries(MIGRATIONS_PATH).each do |migration|
          match = /^([0-9]+).*\.rb$/.match(migration)
          if match then
            version = match[1].to_i
            max_version = version if version > max_version
          end
        end
        max_version
      end

      ##
      #Migrates to the target version
      def migrate(target = nil)
        target ||= latest_version
        ActiveRecord::Migrator.migrate(MIGRATIONS_PATH, target)
      end
    end

    ##
    #Contains database-related configuration options
    class Config
      include ConfigClass

      #The database type
      #
      #Corresponds to the ActiveRecord database adapter name
      property :db_type, type: String
      #The database server's hostname
      property :server, type: String
      #The database server's port
      #
      #If nil, the default port will be used.
      property :port, type: Integer, allow_nil: true
      #The name of the database to use
      property :database, type: String
      #The username for the database
      property :username, type: String
      #The password for the database
      property :password, type: String

      #Connects to the database specified in the configuration file
      def connect()
        #To consider: disable colorized logging?
        #To consider: create config option for this?
        #ActiveRecord::Base.logger = Logger.new(STDERR)
        #ActiveRecord::Base.logger.level = Logger::WARN
        ActiveRecord::Base.time_zone_aware_attributes = true
        ActiveRecord::Base.default_timezone = :utc
        ActiveRecord::Base.establish_connection(
          adapter:  self.db_type,
          database: self.database,
          username: self.username,
          password: self.password,
          host:     self.server,
          port:     self.port)
      end
    end
  end
end
