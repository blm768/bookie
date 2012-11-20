module TorqueStats
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
    
    #Yields each completed job to the given block
    def each_job
      @file.rewind
      @file.each_line do |line|
        #Skip the timestamp.
        index = line.index(';')
        next unless index
        
        #Find the event type.
        event_type = line[index + 1]
        next unless event_type == ?E
        
        job = Job.new()
        
        #Find the fields.
        index = line.index(';', index + 3) + 1
        fields = line[index .. -1].split(' ')
        
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
    
    #Parses a duration in HH:MM:SS format, returning seconds
    #To do: make class method?
    def parse_duration(str)
      hours, minutes, seconds = *str.split(':').map!{ |s| Integer(s) }
      return hours * 3600 + minutes * 60 + seconds
    end
    protected :parse_duration
  end
  
  class << self;
    #The TORQUE root directory (usually the value of the environment variable TORQUEROOT)
    attr_accessor :torque_root
    
    def filename_for_date(date)
      File.join(TorqueStats::torque_root, 'server_priv', 'accounting', date.strftime("%Y%m%d"))
    end
  end
  @torque_root = ENV['TORQUEROOT'] || '/var/spool/torque'
  
end