
module Bookie
  module Senders
    ##
    #Returns data from a TORQUE cluster log
    module TorqueCluster
      #Yields each job in the log
      def each_job(filename)
        record = Torque::JobLog.new(filename)
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

##
#Contains tools for working with TORQUE data
module Torque
  #Represents a completed job
  class Job
    #The name of the user who created the job
    attr_accessor :user_name
    #The group name of the user who created the job
    attr_accessor :group_name
    #The job's start time
    attr_accessor :start_time
    #The job's total wall time
    attr_accessor :wall_time
    #The job's total CPU time
    attr_accessor :cpu_time
    #The job's maximum physical memory usage in kilobytes
    attr_accessor :physical_memory
    #The job's maximum virtual memory usage in kilobytes
    attr_accessor :virtual_memory
    #The job's exit code
    attr_accessor :exit_code
    
    #Returns the job's total maximum memory usage in kilobytes
    def memory
      physical_memory + virtual_memory
    end
  end
  
  #Represents a job record file
  class JobLog
    #The name of the accounting file opened
    attr_reader :filename
  
    #Creates a JobRecord using the TORQUE record file for the given date
    def initialize(filename)
      @filename = filename
      @file = File.open(filename)
    end
    
    ##
    #Raised when a line in the file is invalid
    class InvalidLineError < RuntimeError
      def initialize(filename, line_num)
        super("Line #{line_num} of file '#{filename}' is invalid.")
      end
    end
    
    ##
    #Yields each completed job to the given block
    def each_job
      @file.rewind
      line_num = 0
      @file.each_line do |line|
        line_num += 1
        next if line.strip! == ''
        #Skip the timestamp.
        index = line.index(';')
        raise invalid_line_error(line_num) unless index
        
        #Find the event type.
        event_type = line[index + 1]
        old_index = index
        index = line.index(';', index + 1)
        raise invalid_line_error(line_num) unless index == old_index + 2
        next unless event_type == ?E
        
        #Find the fields.
        index = line.index(';', index + 1)
        raise invalid_line_error(line_num) unless index
        fields = line[index + 1 .. -1].split(' ')
        
        job = Job.new()
        
        #To do: make sure all fields are present?
        fields.each do |field|
          key, value = *field.split('=')
          case key
            when "user"
              job.user_name = value
            when "group"
              job.group_name = value
            when "start"
              job.start_time = Time.at(Integer(value))
            when "resources_used.walltime"
              job.wall_time = parse_duration(value)
            when "resources_used.cput"
              job.cpu_time = parse_duration(value)
            when "resources_used.mem"
              job.physical_memory = Integer(value[0 ... -2])
            when "resources_used.vmem"
              job.virtual_memory = Integer(value[0 ... -2])
            when "Exit_status"
              job.exit_code = Integer(value)
          end
        end
        
        yield job
      end
    end
    
    ##
    #Creates an InvalidLineError associated with this object's file
    def invalid_line_error(line_num)
      InvalidLineError.new(@filename, line_num)
    end
    protected :invalid_line_error
    
    ##
    #Parses a duration in HH:MM:SS format, returning seconds
    #--
    #To do: make class method?
    #++
    def parse_duration(str)
      hours, minutes, seconds = *str.split(':').map!{ |s| Integer(s) }
      return hours * 3600 + minutes * 60 + seconds
    end
    protected :parse_duration
    
    ##
    #Converts a date to the name of the file holding entries for that date
    def self.filename_for_date(date)
      File.join(Torque::torque_root, 'server_priv', 'accounting', date.strftime("%Y%m%d"))
    end
  end
  
  class << self;
    #The TORQUE root directory (usually the value of the environment variable TORQUEROOT)
    attr_accessor :torque_root
  end
  #To consider: make class variable? Constant?
  @torque_root = ENV['TORQUEROOT'] || '/var/spool/torque'
end

module Torque
  class Job
    include Bookie::ModelHelpers
  end
end