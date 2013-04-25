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
        #To do: tighten conditions for duplicate detection?
        raise "Jobs already exist in the database for '#{filename}'." if duplicate
        time_min = job.start_time
        time_max = end_time
        break
      end
      
      #If there are no jobs, return.
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
      date_min = time_min.to_date
      date_max = time_max.to_date
      
      Database::JobSummary.by_system(system).where('date >= ? AND date <= ?', date_min, date_max).delete_all
    end
    
    ##
    #Undoes a previous send operation
    def undo_send(filename)
      raise IOError.new("File '#{filename}' does not exist.") unless File.exists?(filename)
      
      system = nil
      
      time_min, time_max = nil
      
      #Grab data from the first job:  
      each_job(filename) do |job|
        next if filtered?(job)
        end_time = job.start_time + job.wall_time
        system = Bookie::Database::System.find_current(self, end_time)
        time_min = job.start_time
        time_max = end_time
        break
      end
      
      return unless time_min
      
      each_job(filename) do |job|
        next if filtered?(job)
        if system.end_time && job.end_time > system.end_time
          system = Database::System.find_current(self, job.end_time)
        end
        #To consider: optimize this query?
        model = Database::Job.where({
          :start_time => job.start_time,
          :wall_time => job.wall_time,
          :system_id => system.id,
          :command_name => job.command_name,
          :cpu_time => job.cpu_time,
          :memory => job.memory,
          :exit_code => job.exit_code
        }).by_user_name(job.user_name).by_group_name(job.group_name).first
        break unless model
        time_min = (model.start_time < time_min) ? model.start_time : time_min
        time_max = (model.end_time > time_max) ? model.end_time : time_max
        model.delete
      end
      
      date_min = time_min.to_date
      date_max = time_max.to_date
      
      Database::JobSummary.where('date >= ? AND date <= ?', date_min, date_max).delete_all
    end
    
    ##
    #The name of the Bookie::Database::SystemType that systems using this sender will have
    def system_type
      #To consider: cache?
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