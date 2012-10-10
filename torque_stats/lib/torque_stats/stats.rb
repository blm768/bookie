module TorqueStats
  class Job
    attr_accessor :user_name
    attr_accessor :group_name
    attr_accessor :start_time
    attr_accessor :wall_time
    attr_accessor :cpu_time
    attr_accessor :exit_code
  end
  
  class JobRecord
    def initialize(filename)
      @file = File.open(filename)
    end
    
    def each_job
      @file.rewind
      @file.each_line do |line|
        index = line.index(';')
        next unless index
        
        event_type = line[index + 1]
        next unless event_type = 'e'
        
        job = Job.new()
        
        yield job
      end
    end
  end
end