require 'bookie/config'
require 'bookie/extensions'

require 'active_record'

##
#Contains database-related code and models
module Bookie::Database
  ##
  #Location of database migrations
  MIGRATIONS_PATH = File.expand_path('./database/migrations/', File.dirname(__FILE__))

  class << self;
    ##
    #Finds the latest database version (the highest migration version)
    def latest_version
      ActiveRecord::Migrator.migrations(MIGRATIONS_PATH).last.version
    end

    ##
    #Migrates to the target version
    def migrate(target = latest_version)
      ActiveRecord::Migrator.migrate(MIGRATIONS_PATH, target)
    end
  end

  ##
  #The base class for all Bookie model objects
  #
  #Allows Bookie to use its own database connection that is independent
  #from other connections in the same app
  class Model < ActiveRecord::Base
    self.abstract_class = true
  end

  ##
  #The base class for Bookie migrations
  #
  #Uses the database connection from Bookie::Database::Model
  #(Or it would if that were working...)
  class Migration < ActiveRecord::Migration
    #TODO: put this back.
    #def connection
    #  Model.connection
    #end
  end

  ##
  #Contains database-related configuration options
  class Config
    DEFAULT_PATH = '/etc/bookie/database.rb'

    include Bookie::ConfigClass

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

    ##
    #Connects to the database specified in the configuration file
    #TODO: remove the model_class hack. (Needed for migrations)
    def connect(model_class = Model)
      #To consider: disable colorized logging?
      #TODO: create config option for this?
      #ActiveRecord::Base.logger = Logger.new(STDERR)
      #ActiveRecord::Base.logger.level = Logger::WARN
      model_class.time_zone_aware_attributes = true
      model_class.default_timezone = :utc
      model_class.establish_connection(
        adapter:  self.db_type,
        database: self.database,
        username: self.username,
        password: self.password,
        host:     self.server,
        port:     self.port)
    end
  end
end

#These go down here because of circular dependencies.
#TODO: remove?
require 'bookie/database/job'
require 'bookie/database/job_summary'
require 'bookie/database/system'
require 'bookie/database/system_type'
require 'bookie/database/system_capacity'
require 'bookie/database/user'
