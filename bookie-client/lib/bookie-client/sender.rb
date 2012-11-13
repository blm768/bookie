require 'bookie'

require 'active_record'
require 'date'
require 'logger'
require 'system_stats'

module Bookie
  module Sender
    #An object that sends data to the server
    class Sender
      #==Parameters
      #* config: an instance of Bookie::Config
      def initialize(config)
        @config = config
        #To do: move to local variable in method?
        @cores = SystemStats::LocalStats.new.num_cores
        t = @config.system_type
        require "bookie-client/senders/#{t}"
        extend Bookie::Sender.const_get(t.camelize)
        #To do: ensure that all required methods were mixed in?
      end
      
      #Sends job data from the given file to the database server
      def send_data(filename)
        hostname = @config.hostname
        system_type = self.system_type
        #Make sure this machine is in the database.
        #This code shouldn't need locks because no other system has the same hostname
        #To do: discuss the above.
        system = Bookie::Database::System.find_by_specs(hostname, system_type, @cores)
        unless system
          #Verify that all previous systems with this name have been decommissioned.
          conflicting_system = Bookie::Database::System.conflicting_systems(hostname).first
          if conflicting_system
            $stderr.puts "The specifications on record for '#{hostname}' do not match this system's specifications."
            $stderr.puts "Please make sure that all previous systems with this hostname have been marked as decommissioned."
            #To do: custom error class?
            raise "System specifications do not match those in the database"
          end
          #If there's no conflict, create the system in the database.
          system = Bookie::Database::System.create!(
            :name => hostname,
            :system_type => system_type,
            :start_time => Time.now.utc,
            :cores => @cores)
        end
        
        #The next day to be processed
        next_datetime = nil
        potential_duplicate_job = nil
        found_duplicate_jobs = 0
        
        known_users = {}
        known_groups = {}
        
        each_job(filename) do |job|
          next if filtered?(job)
          db_job = job.to_model
          #Should we move on to the next day?
          #To do: how does this cooperate with time zone changes? DST?
          if !next_datetime || db_job.end_time >= next_datetime
            current_date = db_job.end_time.to_date
            next_datetime = current_date.next_day.to_time
            #Determine if there could be duplicate jobs already in the database for this day.
            potential_duplicate_job = Bookie::Database::Job.by_end_time_range(
              current_date.to_time,
              next_datetime).first 
            if potential_duplicate_job
              if potential_duplicate_job.end_time >= job.start_time + job.wall_time
                date_str = current_date.strftime("%Y-%m-%d")
                $stderr.puts("Warning: jobs already exist in the database for the date #{date_str}.")
              else
                potential_duplicate_job = nil
              end
            end
          end
          #Determine if the user/group pair must be added to/retrieved from the database.
          user = Bookie::Database::User.find_or_create(
            job.user_name,
            job.group_name,
            known_users,
            known_groups)
          db_job.system = system
          db_job.user = user
          #Is this job a duplicate of one in the database?
          #To do: remove.
          if potential_duplicate_job && db_job.duplicates.first
            #This is almost certainly a duplicate.
            #To do: perform a more exhaustive check here?
            found_duplicate_jobs += 1
            #Skip the duplicate.
            next
          end
          db_job.save!
        end
        
        if found_duplicate_jobs > 0
          #To do: clearer message?
          if found_duplicate_jobs == 1
            $stderr.puts "Warning: 1 job entry was not sent because it appears to be a duplicate of an entry already in the database."
          else
            $stderr.puts "Warning: #{found_duplicate_jobs} job entries were not sent because they appear to be duplicates of entries already in the database."
          end
        end
      end
      
      #This must not be called when table locks are held.
      #
      #To do: check for name collision issues?
      def system_type
        ActiveRecord::Base.connection.execute('LOCK TABLES system_types WRITE')
        type_name = self.system_type_name
        st = Bookie::Database::SystemType.find_by_name(type_name)
        unless st
          st = Bookie::Database::SystemType.create(
            :name => type_name,
            :memory_stat_type => self.memory_stat_type
          )
        end
        st
      ensure
        ActiveRecord::Base.connection.execute('UNLOCK TABLES')
      end
      
      #Filters a job to see if it should be included in the final output
      #
      #Returns either the given job or nil
      def filtered?(job)
        @config.excluded_users.include?job.user_name
      end
      
      #Decommissions the specified system by setting its end time in the database
      #
      #Neither argument should be nil.
      def decommission(hostname, end_time)
        #To do: does this need locks?
        system = Bookie::Database::System.where(
          'name = ? AND end_time IS NULL',
          hostname).first
        if system
          system.end_time = end_time
          system.save!
        else
          $stderr.puts "No active system with hostname '#{hostname}' found"
          #To do: raise error here?
        end
      end
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
        db_job.job_id = self.job_id
        db_job.array_id = self.array_id
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