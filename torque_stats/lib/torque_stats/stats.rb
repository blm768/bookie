module TorqueStats
  class Job
    attr_accessor :user_name
    attr_accessor :group_name
    attr_accessor :start_time
    attr_accessor :wall_time
    attr_accessor :cpu_time
    attr_accessor :physical_memory
    attr_accessor :virtual_memory
    attr_accessor :exit_code
    
    def memory
      physical_memory + virtual_memory
    end
  end
  
  class JobRecord
    attr_reader :filename
  
    def initialize(date)
      @filename = File.join(TorqueStats::torque_root, 'server_priv', 'accounting', date.strftime("%Y%m%d"))
      @file = File.open(filename)
    end
    
    def each_job
      @file.rewind
      @file.each_line do |line|
        index = line.index(';')
        next unless index
        
        event_type = line[index + 1]
        next unless event_type = 'e'
        
        index = line.index(';', index + 3) + 1
        fields = line[index .. -1].split(' ')
        
        job = Job.new()
        
        fields.each do |field|
          key, value = *field.split('=')
          case key
            when "user"
              job.user_name = value
            when "group"
              job.group_name = value
            when "Exit_status"
              job.exit_code = Integer(value)
          end
        end
        
        yield job
      end
    end
  end
  
  class << self; attr_accessor :torque_root end
  torque_root = ENV['TORQUEROOT'] || '/var/spool/torque'
end