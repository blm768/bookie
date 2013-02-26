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
      summaries = {}
      
      #Check the first job to see if there are entries in the database for its date from this system.
      each_job(filename) do |job|
        next if filtered?(job)
        end_time = job.start_time + job.wall_time
        duplicate = system.jobs.find_by_end_time(end_time)
        if duplicate
          raise "Jobs already exist in the database for '#{filename}'."
        end
        break
      end
      
      #To do: use old versions of the system when jobs match those!
      
      each_job(filename) do |job|
        next if filtered?(job)
        model = job.to_model
        user = Bookie::Database::User.find_or_create!(
          job.user_name,
          Bookie::Database::Group.find_or_create!(job.group_name, known_groups),
          known_users
        )
        model.system = system
        model.user = user
        model.save!
        key = [job.start_time.to_date, model.user, model.system, job.command_name]
        summary = summaries[key]
        summary ||= [0, 0, 0, 0]
        summary[0] += 1
        summary[1] += job.cpu_time
        summary[2] += job.wall_time * job.memory
        summary[3] += 1 if job.exit_code == 0
        summaries[key] = summary
      end
      
      known_summaries = {}
      
      summaries.each do |key, values|
        sum = Database::JobSummary.find_or_new(*key, known_summaries)
        sum.with_lock do
          sum.num_jobs = values[0]
          sum.cpu_time = values[1]
          sum.memory_time = values[2]
          sum.successful = values[3]
        end
        sum.save!
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