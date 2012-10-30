require 'bookie'

require 'active_record'
require 'date'
require 'digest/md5'
require 'fileutils'
require 'logger'
require 'system_stats'
require 'torque_stats'
require 'socket'

module Bookie
  module Client
    #Abstract class defining the interface for a data sender
    class Sender
      #==Parameters
      #* config: an instance of Bookie::Config
      def initialize(config)
        @config = config
        #To do: move to local variable in method?
        @cores = SystemStats::LocalStats.new.num_cores
      end
      
      #Sends job data for a given day to the database server
      #
      #If the date parameter is nil, records for the current day are processed.
      def send_data(date = nil)
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
          system = Bookie::Database::System.new
          system.name = hostname
          system.system_type = system_type
          system.start_time = Time.new
          system.cores = @cores
          system.save!
        end
        
        #The next day to be processed
        next_datetime = nil
        potential_duplicate_job = nil
        found_duplicate_jobs = 0
        
        existing_users = {}
        
        each_job(date) do |job|
          next unless filter_job(job)
          db_job = to_database_job(job)
          #Should we move on to the next day?
          if !next_datetime || db_job.end_time >= next_datetime
            current_date = db_job.end_time.to_date
            next_datetime = current_date.next_day.to_time
            #Determine if there could be duplicate jobs already in the database for this day.
            #To do: see if all jobs in the DB are before this one.
            potential_duplicate_job = Bookie::Filter::by_end_time(
              Bookie::Database::Job,
              current_date.to_time,
              next_datetime).first
            if potential_duplicate_job
              #To do: send this to a logger instead?
              date_str = current_date.strftime("%Y-%m-%d")
              $stderr.puts("Warning: jobs already exist in the database for the date #{date_str}.")
            end
          end
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
          #Determine if the user/group pair must be added to/retrieved from the database.
          user = existing_users[[job.user_name, job.group_name]]
          unless user
            #Does the group exist?
            #To do: optimize!
            group = nil
            Bookie::Database::Group.transaction do
              group = Bookie::Database::Group.where(:name => job.group_name).first
              unless group
                group = Bookie::Database::Group.new
                group.name = job.group_name
                group.save!
              end
            end
            #Does the user already exist?
            #To do: optimize!
            Bookie::Database::User.transaction do
              user = Bookie::Database::User.where(:name => job.user_name, :group_id => group.id).first
              unless user
                user = Bookie::Database::User.new
                user.name = job.user_name
                user.group = group
                user.save!
              end
              existing_users[[job.user_name, job.group_name]] = user
            end
          end
          db_job.system = system
          db_job.user = user
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
      
      #Yields each job, sorted by end time
      #
      #If log rotation is required, this should also be performed here. For now.
      def each_job(date)
        raise NotImplementedError.new("Must be defined by subclass")
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
        db_job.end_time = job.start_time + job.wall_time
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

    #Represents a client that returns data from a standalone Linux system
    class LinuxSender < Sender
      #Yields each job in the log
      def each_job(date = nil)
        #To do: modify for production.
        base_dir = 'snapshot'
        base_filename = File.join(base_dir, 'pacct')
        log_base_filename = File.join(@config.log_dir, 'var/account/pacct')
        #Are we reading an old log?
        if date
          filename = log_base_filename + date.strftime(".%Y.%m.%d")
          file = Pacct::File.new(filename)
          file.each_entry do |job|
            yield job
          end
        else
          begin
            file = Pacct::File.new(base_filename)
            bookmark_filename = log_base_filename + ".bookmark"
            start = 0
            current_entry = nil
            #If there's a bookmark from previous processing, use it.
            if File.file?(bookmark_filename)
              #To do: better checking?
              start = File.read(bookmark_filename).to_i
            end
            rotation_file = nil
            rotation_end_time = Time.at(0)
            file.each_entry(start) do |job, index|
              current_entry = index
              job_end_time = job.start_time + job.wall_time
              #Is it time for a new rotation file?
              if job_end_time >= rotation_end_time || !rotation_file
                rotation_start_date = job_end_time.to_date
                rotation_end_time = rotation_start_date.next_day.to_time
                rotation_filename = log_base_filename + rotation_start_date.strftime(".%Y.%m.%d")
                rotation_file = Pacct::File.new(rotation_filename)
                #Did this file already contain data?
                if rotation_file.num_entries > 0
                  #See if we can just append.
                  last = rotation_file.last_entry
                  if last.start_time + last.wall_time >= job.start_time + job.wall_time
                    #To do: clearer message?
                    raise "Error: log file '#{rotation_filename}' contains entries newer than those in #{base_filename}."
                  end
                end
              end
              yield job
              rotation_file.write_entry(job)
            end
          rescue => e
            #Set a bookmark so we can start here next time.
            if current_entry then
              bookmark_file = File.open(bookmark_filename, "w")
              bookmark_file.puts current_entry
            end
            raise e
          end
          #To do: uncomment for production.
          #To do: verify that this doesn't kill accounting.
          #FileUtils.rm(base_filename)
          FileUtils.rm(bookmark_filename) if File.exists?(bookmark_filename)
        end
      end
      
      def system_type_name
        return "Standalone (Linux)"
      end
      
      def memory_stat_type
        return :avg
      end
    end
    
    class TorqueSender < Sender
      #Yields each job in the log
      def each_job(date = nil)
        date ||= Date.today
        record = TorqueStats::JobRecord.new(date)
        record.each_job do |job|
          yield job
        end
      end
      
      def system_type_name
        return "TORQUE cluster"
      end
      
      def memory_stat_type
        return :max
      end
    end
  end
end