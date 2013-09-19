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
      sys_type = config.system_type
      require "bookie/senders/#{sys_type}"
      extend Bookie::Senders.const_get(sys_type.camelize)
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
        system = Bookie::Database::System.find_current(self, job.end_time)
        raise "Jobs already exist in the database for '#{filename}'." if duplicate(job, system)
        time_min = job.start_time
        time_max = job.end_time
        break
      end
      
      #If there are no jobs, return.
      return unless time_min
      
      #Send the job data:
      each_job(filename) do |job|
        next if filtered?(job)
        model = job.to_model
        time_min = (model.start_time < time_min) ? model.start_time : time_min
        time_max = (model.end_time > time_max) ? model.end_time : time_max
        #To consider: handle files that don't have jobs sorted by end time?
        #To consider: this should rarely happen in real life. Remove test?
        #(This situation can only arise if log files from different versions of the system are concatenated before sending.)
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
      clear_summaries(time_min.to_date, time_max.to_date)
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
        system = Bookie::Database::System.find_current(self, job.end_time)
        time_min = job.start_time
        time_max = job.end_time
        break
      end
      
      return unless time_min
      
      each_job(filename) do |job|
        next if filtered?(job)
        if system.end_time && job.end_time > system.end_time
          system = Database::System.find_current(self, job.end_time)
        end
        #TODO: optimize this query?
        #(It should be possible to delete all of the jobs with end times between those of the first and last jobs of the file (exclusive),
        #but jobs with end times matching those of the first/last jobs in the file might be from an earlier or later file, not this one.
        #This assumes that the files all have jobs sorted by end time.
        model = duplicate(job, system)
        break unless model
        time_min = (model.start_time < time_min) ? model.start_time : time_min
        time_max = (model.end_time > time_max) ? model.end_time : time_max
        model.delete
      end
      
      clear_summaries(time_min.to_date, time_max.to_date)
    end
    
    ##
    #The name of the Bookie::Database::SystemType that systems using this sender will have
    def system_type
      @system_type ||= Bookie::Database::SystemType.find_or_create!(system_type_name, memory_stat_type)
    end
    
    ##
    #Returns whether a job should be filtered from the results
    #
    def filtered?(job)
      @config.excluded_users.include?job.user_name
    end
    
    ##
    #Finds the first job that is a duplicate of the provided job
    def duplicate(job, system)
      system.jobs.where({
          :start_time => job.start_time,
          :wall_time => job.wall_time,
          :command_name => job.command_name,
          :cpu_time => job.cpu_time,
          :memory => job.memory,
          :exit_code => job.exit_code
        }).by_user_name(job.user_name).by_group_name(job.group_name).first
    end
    
    #Used internally by #send_data and #undo_send
    def clear_summaries(date_min, date_max)      
      #Since joins don't mix with DELETE statements, we have to do this the hard way.
      systems = Database::System.by_name(@config.hostname).to_a
      systems.map!{ |sys| sys.id }
      Database::JobSummary.where('job_summaries.system_id in (?)', systems).where('date >= ? AND date <= ?', date_min, date_max).delete_all
    end
    private :clear_summaries
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
      job.wall_time = self.wall_time
      job.cpu_time = self.cpu_time
      job.memory = self.memory
      job.exit_code = self.exit_code
      job
    end

    ##
    #Returns the end time
    def end_time
      start_time + wall_time
    end
  end

  #Contains all sender plugins
  module Senders
    
  end
end
