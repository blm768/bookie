require 'bookie'

require 'active_record'
require 'date'
require 'logger'

module Bookie
  module Sender
    #An object that sends data to the server
    class Sender
      #==Parameters
      #* config: an instance of Bookie::Config
      def initialize(config)
        @config = config
        t = @config.system_type
        require "bookie-client/senders/#{t}"
        extend Bookie::Sender.const_get(t.camelize)
        #To do: ensure that all required methods were mixed in?
      end
      
      #Retrieves the System object with which the jobs will be associated, creating it if it does not exist
      #
      #To do: caching?
      def system
        hostname = @config.hostname
        system_type = self.system_type
        #Make sure this machine is in the database.
        #This code shouldn't need locks because no other system has the same hostname
        #To do: discuss the above.
        system = Bookie::Database::System.by_name(hostname).active_systems.first
        #Verify that this system's specs match those on file.
        if system
          unless system.name == hostname && system.system_type == system_type && system.cores == @config.cores && system.memory == @config.memory
            #To do: custom error class?
            raise "The specifications on record for '#{hostname}' do not match this system's specifications.
  Please make sure that all previous systems with this hostname have been marked as decommissioned."
          end
        else
          #If the system doesn't exist, create it.
          system = Bookie::Database::System.create!(
            :name => hostname,
            :system_type => system_type,
            :start_time => Time.now.utc,
            :cores => @config.cores,
            :memory => @config.memory)
        end
        system
      end
      
      #Sends job data from the given file to the database server
      def send_data(filename)
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
          user = Bookie::Database::User.find_or_create(
            job.user_name,
            job.group_name,
            known_users,
            known_groups)
          db_job.system = system
          db_job.user = user
          db_job.save!
        end
      end
      
      #To do: check for name collision issues?
      def system_type
        Bookie::Database::SystemType.find_or_create(system_type_name, memory_stat_type)
      end
      
      #Filters a job to see if it should be included in the final output
      #
      #Returns either the given job or nil
      def filtered?(job)
        @config.excluded_users.include?job.user_name
      end
    
    module ModelHelpers
      #Converts the client's internal job type to a Bookie::Database::Job
      #
      #To do:
      #This currently only converts fields that can be handled without a database lookup.
      #It should probably be made to include those. On the other hand, how do I efficiently
      #handle the system field? A parameter?
      def to_model()
        db_job = Bookie::Database::Job.new
        db_job.start_time = self.start_time
        db_job.end_time = self.start_time + self.wall_time
        db_job.wall_time = self.wall_time
        db_job.cpu_time = self.cpu_time
        db_job.memory = self.memory
        #To do: unit tests
        db_job.exit_code = self.exit_code
        return db_job
      end
    end
  end
end