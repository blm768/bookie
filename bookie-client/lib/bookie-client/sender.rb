require 'bookie'

require 'active_record'
require 'logger'
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
      def send_data(date)
        #To do: resolve potential issue w/ reverse lookup?
        #Just use hostname (not FQDN)?                                                                                             
        hostname = Socket.gethostbyname(Socket.gethostname)[0]
        #Make sure this machine is in the database.
        server = Bookie::Database::Server.where(:name => hostname).first
        unless server
          server = Bookie::Database::Server.new
          server.name = hostname
          server.server_type = system_type
          server.save!
        end
        each_job(date) do |job|
          group = Bookie::Database::Group.where(:name => job.group_name).first
          unless group
            group = Bookie::Database::Group.new
            group.name = job.group_name
            group.save!
          end
          user = Bookie::Database::User.where(:name => job.user_name, :group_id => group.id).first
          unless user
            user = Bookie::Database::User.new
            user.name = job.user_name
            user.group = group
            user.save!
          end
          next unless filter_job(job)
          db_job = to_database_job(job)
          db_job.server = server
          db_job.user = user
          db_job.save!
        end
      end
      
      #Yields each job
      def each_job(date)
        raise NotImplementedError.new("Must be defined by subclass")
      end
      
      #Returns the type code of the system
      def system_type
        raise NotImplementedError.new("Must be defined by subclass")
      end
      
      #Rotates the log data if there is a need for rotation
      def rotate_log
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
      def to_database_job(job)
        db_job = Bookie::Database::Job.new
        db_job.start_time = job.start_time
        db_job.end_time = job.start_time + job.wall_time
        db_job.wall_time = job.wall_time
        db_job.cpu_time = job.cpu_time
        db_job.memory = job.memory
        return db_job
      end
    end

    #Represents a client that returns data from a standalone Linux server
    class LinuxSender < Sender
      #Yields each job in the log
      def each_job(date)
        file = Pacct::File.new('snapshot/pacct')
        file.each_entry do |job|
          yield job
        end
      end
      
      def system_type
        return :standalone
      end
    end
  end
end