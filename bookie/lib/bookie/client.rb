require 'bookie'

require 'active_record'
require 'logger'

module Bookie
  #Abstract class defining the interface for a Bookie client
  class Client
    #==Parameters
    #* config: an instance of Bookie::Config
    def initialize(config)
      @config = config
    end
    
    #Sends job data for a given day to the database server
    def send_data(date)
      each_job do
        
      end
    end
    
    #Yields each job
    def each_job(date)
      raise NotImplementedError.new("Must be defined by subclass")
    end
    
    #Filters a job to see if it should be included in the final output
    #
    #Returns either the given job or nil
    def filter_job(job)
      return nil if @config.excluded_users.include?job.user_name
      return job
    end
    
    #Converts the client's internal job type to a Bookie::Database::Job
    def to_database_job(job)
      
    end
  
    #Connects to the database specified in the configuration file
    def connect()
      #To do: this is deprecated; find alternative?
      #ActiveRecord.colorize_logging = false
      ActiveRecord::Base.logger = Logger.new(STDERR)
      ActiveRecord::Base.establish_connection(
        :adapter  => @config.db_type,
        :database => @config.database,
        :username => @config.username,
        :password => @config.password,
        :host     => @config.server,
        :port     => @config.port)
    end
  end
end
