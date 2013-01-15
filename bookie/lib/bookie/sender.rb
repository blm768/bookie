require 'bookie/database'

require 'date'

module Bookie
  ##
  #An object that sends data to the database
  class Sender
    ##
    #Creates a new Sender
    #
    #<tt>config</tt> should be an instance of Bookie::Config.
    def initialize(config)
      @config = config
      t = @config.system_type
      require "bookie/senders/#{t}"
      extend Bookie::Senders.const_get(t.camelize)
    end
    
    ##
    #Retrieves the System object with which the jobs will be associated
    #--
    #To consider: caching?
    #++
    def system
      hostname = @config.hostname
      system_type = self.system_type
      Bookie::Database::System.find_active(
        :name => hostname,
        :system_type => system_type,
        :start_time => Time.now,
        :cores => @config.cores,
        :memory => @config.memory
      )
    end
    
    ##
    #Sends job data from the given file to the database server
    def send_data(filename)
      raise IOError.new("File '#{filename}' does not exist.") unless File.exists?(filename)
    
      system = self.system
      
      known_users = {}
      known_groups = {}
      
      #Check the first job to see if there are entries in the database for its date from this system.
      each_job(filename) do |job|
        next if filtered?(job)
        end_time = job.start_time + job.wall_time
        duplicate = system.jobs.find_by_end_time(end_time)
        if duplicate
          raise "Jobs already exist in the database for the date #{end_time.strftime('%Y-%m-%d')}."
        end
        break
      end
      
      each_job(filename) do |job|
        next if filtered?(job)
        db_job = job.to_model
        #Determine if the user/group pair must be added to/retrieved from the database.
        user = Bookie::Database::User.find_or_create!(
          job.user_name,
          Bookie::Database::Group.find_or_create!(job.group_name, known_groups),
          known_users)
        db_job.system = system
        db_job.user = user
        db_job.save!
      end
    end
    
    ##
    #The name of the Bookie::Database::SystemType that systems using this sender will have
    def system_type
      Bookie::Database::SystemType.find_or_create!(system_type_name, memory_stat_type)
    end
    
    ##
    #Returns whether a job should be filtered from the results
    #
    def filtered?(job)
      @config.excluded_users.include?job.user_name
    end
  end
  
  ##
  #This module is mixed into various job classes used internally by senders.
  module ModelHelpers
    ##
    #Converts the object to a Bookie::Database::Job
    def to_model()
      db_job = Bookie::Database::Job.new
      db_job.start_time = self.start_time
      db_job.end_time = self.start_time + self.wall_time
      db_job.wall_time = self.wall_time
      db_job.cpu_time = self.cpu_time
      db_job.memory = self.memory
      db_job.exit_code = self.exit_code
      return db_job
    end
  end
  
  #Contains all sender plugins
  module Senders
    
  end
end