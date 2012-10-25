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
      end
      
      #Sends job data for a given day to the database server
      #To do: actually make the date parameter meaningful; it is currently ignored.
      def send_data(date)
        #To do: resolve potential issue w/ reverse lookup?
        #Just use hostname (not FQDN)?
        hostname = Socket.gethostbyname(Socket.gethostname)[0]
        #To do: optimize.
        cores = SystemStats::LocalStats.new.num_cores
        #Make sure this machine is in the database.
        #To do: check for different # of cores
        #Make sure only one server w/ a given name has a NULL end_time
        server = Bookie::Database::Server.where(
          'name = ? AND cores = ? AND end_time IS NULL',
          hostname, cores).first
        unless server
          server = Bookie::Database::Server.new
          server.name = hostname
          server.server_type = system_type
          #To do: restore for production.
          #server.start_time = Time.new
          server.start_time = Date.new(2012, 1, 1).to_time
          server.cores = cores
          server.save!
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
            #To do: warn even if no jobs are actually duplicates?
            potential_duplicate_job = Bookie::Filter::by_end_time(
              Bookie::Database::Job,
              current_date.to_time,
              next_datetime).first
          end
          #Is this job a duplicate of one in the database?
          if potential_duplicate_job && Bookie::Database::Job.where(
              'server_id = ? AND job_id = ? AND array_id = ? AND start_time = ?',
              server.id,
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
            group = Bookie::Database::Group.where(:name => job.group_name).first
            unless group
              group = Bookie::Database::Group.new
              group.name = job.group_name
              group.save!
            end
            #Does the user already exist?
            #To do: optimize!
            user = Bookie::Database::User.where(:name => job.user_name, :group_id => group.id).first
            unless user
              user = Bookie::Database::User.new
              user.name = job.user_name
              user.group = group
              user.save!
            end
            existing_users[[job.user_name, job.group_name]] = user
          end
          db_job.server = server
          db_job.user = user
          db_job.save!
        end
        
        if found_duplicate_jobs > 0
          #To do: clearer message?
          $stderr.puts "Warning: #{found_duplicate_jobs} job entries were not sent because they appear to be duplicates of entries already in the database."
        end
      end
      
      #Yields each job, sorted by end time
      #
      #If log rotation is required, this should also be performed here. For now.
      def each_job(date)
        raise NotImplementedError.new("Must be defined by subclass")
      end
      
      #Returns the type code of the system
      def system_type
        raise NotImplementedError.new("Must be defined by subclass")
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
      #handle the server field? A parameter?
      def to_database_job(job)
        db_job = Bookie::Database::Job.new
        #To do: make more general?
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
    end

    #Represents a client that returns data from a standalone Linux server
    class LinuxSender < Sender
      #Yields each job in the log
      #
      #To do: do something with the date parameter.
      def each_job(date)
        #To do: modify for production.
        base_filename = 'snapshot/pacct'
        #To do: What if this doesn't exist (when pulling up archives and the given date isn't found)?
        file = Pacct::File.new(base_filename)
        rotation_file = nil
        rotation_end_time = Time.at(0)
        file.each_entry do |job|
          yield job
          job_end_time = job.start_time + job.wall_time
          if job_end_time >= rotation_end_time || !rotation_file
            rotation_start_date = job_end_time.to_date
            rotation_end_time = rotation_start_date.next_day.to_time
            rotation_filename = base_filename + rotation_start_date.strftime(".%Y.%m.%d")
            if File.exists?rotation_filename
              $stderr.puts "Warning: log file '#{rotation_filename}' already exists. Overwriting."
              #To do: what if this fails?
              FileUtils.rm(rotation_filename)
            end
            rotation_file = Pacct::File.new(rotation_filename)
          end
          rotation_file.write_entry(job)
        end
        #To do: uncomment for production.
        #FileUtils.rm(base_filename)
      end
      
      def system_type
        return :standalone
      end
    end
    
    class TorqueSender < Sender
      #Yields each job in the log
      def each_job(date)
        record = TorqueStats::JobRecord.new(date)
        record.each_job do |job|
          yield job
        end
      end
      
      def system_type
        return :torque_cluster
      end
    end
  end
end