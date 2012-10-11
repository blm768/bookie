require 'bookie'

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
      raise NotImplementedError
    end
    
    #Filters a job to see if it should be included in the final output
    #
    #Returns either the given job or nil
    def filter_job(job)
      return nil if @config.excluded_users.include?job.user_name
      return job
    end
  end
end
