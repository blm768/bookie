require 'bookie'

require 'active_record'
require 'date'
require 'logger'
require 'system_stats'

module Bookie
  module Sender
    #Abstract class defining the interface for a data sender
    class Sender
      #==Parameters
      #* config: an instance of Bookie::Config
      def initialize(config)
        @config = config
        #To do: move to local variable in method?
        @cores = SystemStats::LocalStats.new.num_cores
      end
      
      @@senders = {}
      
      def self.by_name(name)
        sender_class = @@senders[name]
        unless sender_class
          filename = name.gsub(/\s+/, "_").downcase
          require "bookie-client/senders/#{filename}"
          sender_class = Bookie::Sender.const_get(filename.camelize)
        end
        return sender_class
      end
      
      #Sends job data for a given day to the database server
      #
      #If the filename parameter is nil, records relevant to the current day are processed.
      #If the filename parameter is a Date object, the file for that date is processed.
      #If the filename parameter is the symbol :flush, all records that would normally
      #be left for the next day are sent.
      def send_data(filename = nil)
        if filename.class == Date
          filename = filename_for_date(filename)
        end
        hostname = @config.hostname
        system_type = self.system_type
        #Make sure this machine is in the database.
        #This code shouldn't need locks because no other system has the same hostname
        #To do: discuss the above.
        system = Bookie::Database::System.where(
          'name = ? AND system_type_id = ? AND cores = ? AND end_time IS NULL',
          hostname, system_type.id, @cores).first
        unless system
          #Verify that all previous systems with this name have been decommissioned.
          conflicting_system = Bookie::Database::System.where(
            'name = ? AND end_time IS NULL',
            hostname).first
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
        
        existing_users = {}
        
        each_job = nil
        if filename == :flush
          each_job = method(:flush_jobs)
          filename = nil
        else
          each_job = method(:each_job)
        end
        
        each_job(filename) do |job|
          next unless filter_job(job)
          db_job = to_database_job(job)
          #Should we move on to the next day?
          #To do: how does this cooperate with time zone changes? DST?
          if !next_datetime || db_job.end_time >= next_datetime
            current_date = db_job.end_time.to_date
            next_datetime = current_date.next_day.to_time
            #Determine if there could be duplicate jobs already in the database for this day.
            potential_duplicate_job = Bookie::Filter::by_end_time(
              Bookie::Database::Job,
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
          user = existing_users[[job.user_name, job.group_name]]
          unless user
            #Does the group exist?
            #To do: optimize!
            group = nil
            Bookie::Database::Group.transaction do
              group = Bookie::Database::Group.find_by_name(job.group_name)
              unless group
                #To do: note that this is another reason for the current duck-typing system.
                group = Bookie::Database::Group.create!(:name => job.group_name)
              end
            end
            #Does the user already exist?
            #To do: optimize!
            Bookie::Database::User.transaction do
              user = Bookie::Database::User.find_by_name_and_group_id(job.user_name, group.id)
              unless user
                user = Bookie::Database::User.create!(
                  :name => job.user_name,
                  :group => group)
              end
              existing_users[[job.user_name, job.group_name]] = user
            end
          end
          db_job.system = system
          db_job.user = user
          #Is this job a duplicate of one in the database?
          if potential_duplicate_job && Bookie::Database::Job.joins(:system).where(
              'systems.name = ? AND job_id = ? AND array_id = ? AND jobs.start_time = ?',
              hostname,
              db_job.job_id,
              db_job.array_id,
              db_job.start_time).first
          then
            #This appears to be a duplicate.
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
      def system_type
        ActiveRecord::Base.connection.execute('LOCK TABLES system_types WRITE')
        type_name = self.system_type_name
        st = Bookie::Database::SystemType.find_by_name(type_name)
        unless st
          st = Bookie::Database::SystemType.new
          st.name = type_name
          st.memory_stat_type = self.memory_stat_type
          st.save!
        end
        return st
      ensure
        ActiveRecord::Base.connection.execute('UNLOCK TABLES')
      end
      
      #Filters a job to see if it should be included in the final output
      #
      #Returns either the given job or nil
      def filter_job(job)
        return nil if @config.excluded_users.include?job.user_name
        return job
      end
      
      #Converts the client's internal job type to a Bookie::Database::Job
      #
      #To do:
      #This currently only converts fields that can be handled without a database lookup.
      #It should probably be made to include those. On the other hand, how do I efficiently
      #handle the system field? A parameter?
      def to_database_job(job)
        db_job = Bookie::Database::Job.new
        if job.respond_to? :process_id
          db_job.job_id = job.process_id
          db_job.array_id = 0
        else
          db_job.job_id = job.job_id
          db_job.array_id = job.array_id
        end
        db_job.start_time = job.start_time
        db_job.end_time = db_job.start_time + job.wall_time
        db_job.wall_time = job.wall_time
        db_job.cpu_time = job.cpu_time
        db_job.memory = job.memory
        #To do: unit tests
        db_job.exit_code = job.exit_code
        return db_job
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
  end
end