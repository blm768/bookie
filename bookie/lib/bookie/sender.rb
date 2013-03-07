require 'bookie/database'

require 'date'

module Bookie
  ##
  #An object that sends data to the database
  class Sender
    attr_reader :config
    
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
    #Sends job data from the given file to the database server
    def send_data(filename)
      raise IOError.new("File '#{filename}' does not exist.") unless File.exists?(filename)
    
      system = nil
      
      known_users = {}
      known_groups = {}
      
      time_min, time_max = nil
      
      #Grab data from the first job:  
      each_job(filename) do |job|
        next if filtered?(job)
        end_time = job.start_time + job.wall_time
        system = Bookie::Database::System.find_current(self, end_time)
        duplicate = system.jobs.find_by_end_time(end_time)
        raise "Jobs already exist in the database for '#{filename}'." if duplicate
        time_min = job.start_time
        time_max = end_time
        break
      end
      
      #If there are no jobs, return.
      #To do: unit test this logic.
      return unless time_min
      
      #To do: add an option to resume an interrupted send.
      
      #Send the job data:
      each_job(filename) do |job|
        next if filtered?(job)
        model = job.to_model
        time_min = (model.start_time < time_min) ? model.start_time : time_min
        time_max = (model.end_time > time_max) ? model.end_time : time_max
        #To consider: handle files that don't have jobs sorted by end time?
        if system.end_time && model.end_time > system.end_time
          system = Database::System.find_current(self, model.end_time)
        end
        user = Bookie::Database::User.find_or_create!(
          job.user_name,
          Bookie::Database::Group.find_or_create!(job.group_name, known_groups),
          known_users
        )
        model.system = system
        model.user = user
        model.save!
      end
      
      #Clear out the summaries that would have been affected by the new data:
      #To do: unit test.
      date_min = time_min.to_date
      date_max = time_max.to_date
      
      Database::JobSummary.by_system(system).where('date >= ? AND date <= ?', date_min, date_max).delete_all
    end
    
    ##
    #The name of the Bookie::Database::SystemType that systems using this sender will have
    def system_type
      #To do: cache?
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
      job = Bookie::Database::Job.new
      job.command_name = self.command_name
      job.start_time = self.start_time
      job.end_time = self.start_time + self.wall_time
      job.wall_time = self.wall_time
      job.cpu_time = self.cpu_time
      job.memory = self.memory
      job.exit_code = self.exit_code
      return job
    end
  end
  
  #Contains all sender plugins
  module Senders
    
  end
end