require 'bookie'

require 'active_record'
require 'logger'
require 'socket'

module Bookie
  #Abstract class defining the interface for a Bookie client
  class Client
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
        puts "Creating server"
        server = Bookie::Database::Server.new
        server.name = hostname
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
  
    #Connects to the database specified in the configuration file
    def connect()
      #To do: this is deprecated; find alternative?
      #ActiveRecord.colorize_logging = false
      ActiveRecord::Base.logger = Logger.new(STDERR)
      ActiveRecord::Base.establish_connection(
        :adapter  => @config.db_type,
        :database => @config.database,
        :username => @config.username,
        :password => @config.password,
        :host     => @config.server,
        :port     => @config.port)
    end
  end
end
