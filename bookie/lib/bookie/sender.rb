require 'date'

require 'active_support/inflector/methods'

require 'bookie/database'

module Bookie
  ##
  #Contains configuration settings for Sender objects
  #TODO: unit test anything?
  class SenderConfig
    include ConfigClass

    ##
    #A closure used to filter jobs to be sent
    #
    #It should return <tt>true</tt> if a job is to be sent and <tt>false</tt> otherwise
    property :job_filter, type: Proc, allow_nil: true, create_proxy: false

    builder_class do
      define_method(:filter_jobs) do |&block|
        config.job_filter = block
      end
    end

    ##
    #The system type
    property :system_type, type: String

    ##
    #The system's hostname
    property :hostname, type: String
  end

  ##
  #An object that sends data to the database
  class Sender
    attr_reader :config

    ##
    #Creates a new Sender
    #
    #<tt>config</tt> should be an instance of Bookie::Sender::Config.
    def initialize(config)
      @config = config

      #Include the correct plugin module.
      sys_type = config.system_type
      require "bookie/senders/#{sys_type}"
      #TODO: just create an instance variable instead of extending?
      extend Bookie::Senders.const_get(ActiveSupport::Inflector.camelize(sys_type))
    end

    ##
    #Sends job data from the given file to the database server
    def send_data(filename)
      users_by_id = Hash.new do |h, id|
        h[id] = Database::User.where(id: id).first
      end

      #Used to clear out cached summaries
      time_min, time_max = nil

      #Check for duplicates.
      each_job(filename) do |job|
        next if filtered?(job)
        raise "Jobs already exist in the database for '#{filename}'." if duplicate(job)
        time_min = job.start_time
        time_max = job.end_time
        #Just use the first job in the file.
        break
      end

      #If there are no jobs, return.
      return unless time_min

      #Send the job data:
      each_job(filename) do |job|
        next if filtered?(job)

        model = job.to_record
        time_min = (model.start_time < time_min) ? model.start_time : time_min
        time_max = (model.end_time > time_max) ? model.end_time : time_max

        model.system = system

        #Either find the user or create it.
        model.user = users_by_id[job.user_id] || begin
          users_by_id[job.user_id] = Database::User.create!(id: job.user_id, name: job.user_name)
        end

        model.save!
      end

      #Clear out the summaries that would have been affected by the new data:
      #TODO: warn if this range isn't completely covered by SystemCapacity entries.
      clear_summaries(time_min.to_date, time_max.to_date)
    end

    ##
    #Undoes a previous send operation
    def undo_send(filename)
      time_min, time_max = nil

      #Grab data from the first job:
      #TODO: don't do this?
      each_job(filename) do |job|
        next if filtered?(job)
        time_min = job.start_time
        time_max = job.end_time
        break
      end

      return unless time_min

      each_job(filename) do |job|
        next if filtered?(job)
        #TODO: optimize this operation?
        #(It should be possible to delete all of the jobs with end times between those of the first and last jobs
        #of the file (exclusive), but jobs with end times matching those of the first/last jobs in the file might
        #be from an earlier or later file, not this one.
        #This assumes that the files all have jobs sorted by end time.
        #TODO: note how many jobs were deleted?
        model = duplicate(job)
        break unless model
        time_min = [model.start_time, time_min].min
        time_max = [model.end_time, time_max].max
        model.delete
      end

      clear_summaries(time_min.to_date, time_max.to_date)
    end

    ##
    #The name of the Bookie::Database::SystemType that systems using this sender will have
    def system_type
      @system_type ||= Bookie::Database::SystemType.find_or_create!(system_type_name, memory_stat_type)
    end

    #TODO: doc and test.
    def system
      @system ||= Bookie::Database::System.find_by!(name: config.hostname)
    end

    ##
    #Returns whether a job should be filtered from the results
    #
    def filtered?(job)
      if @config.job_filter then
        not @config.job_filter.call(job)
      else
        false
      end
    end

    ##
    #Finds the first job that is a duplicate of the provided job
    def duplicate(job)
      system.jobs.where({
          command_name: job.command_name,
          user_id: job.user_id,
          start_time: job.start_time,
          wall_time: job.wall_time,
          cpu_time: job.cpu_time,
          memory: job.memory,
          exit_code: job.exit_code
        }).first
    end

    #Used internally by #send_data and #undo_send
    def clear_summaries(date_min, date_max)
      system_id = Database::System.find_by(name: @config.hostname).id
      Database::JobSummary.where(system_id: system_id).where('? <= date AND date <= ?', date_min, date_max).delete_all
    end
    private :clear_summaries
  end

  ##
  #This module is mixed into various job classes used internally by senders.
  module ModelHelpers
    ##
    #Converts the object to a Bookie::Database::Job
    def to_record()
      job = Bookie::Database::Job.new
      job.command_name = self.command_name
      job.start_time = self.start_time
      job.wall_time = self.wall_time
      job.cpu_time = self.cpu_time
      job.memory = self.memory
      job.exit_code = self.exit_code
      job
    end

    def end_time
      start_time + wall_time
    end
  end

  #Contains all sender plugins
  module Senders

  end
end
