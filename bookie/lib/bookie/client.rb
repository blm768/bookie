require 'bookie'

module Bookie
  #Represents a client that can pull data from the server and display tables
  class Client
    def initialize(config)
      @config = config
    end
    
    def print_jobs(jobs, io = $stdout)
      heading = sprintf @@FORMAT_STRING, 'User', 'Group', 'Server', 'Start time',
        'End time', 'Wall time', 'CPU time', 'Memory usage'
      io.write heading
      io.puts '-' * (heading.length - 1)
      jobs.each do |job|   
        io.printf @@FORMAT_STRING,
          job.user.name,
          job.user.group.name,
          job.server.name,
          job.start_time,
          job.end_time,
          Client.format_duration(job.end_time - job.start_time),
          Client.format_duration(job.cpu_time),
          "#{job.memory}kb"
      end
    end
    
    @@FORMAT_STRING = "|%-15.15s|%-15.15s|%-20.20s|%-25.25s|%-25.25s|%-10.10s|%-10.10s|%-20.20s|\n"
    
    def self.format_duration(dur)
      dur = Integer(dur)
      hours = dur / 3600
      minutes = (dur - hours * 3600) / 60
      seconds = dur % 60
      return "#{hours.to_s.ljust(2, '0')}:#{minutes.to_s.ljust(2, '0')[0 .. 1]}:#{seconds.to_s.ljust(2, '0')[0 .. 1]}"
    end
  end
end