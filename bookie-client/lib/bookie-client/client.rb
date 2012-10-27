require 'bookie'

require 'date'
require 'pacct'
require 'spreadsheet'

module Bookie
  module Client
    #Represents a client that can pull data from the server and display tables
    class Client
      def initialize(config)
        @config = config
      end
      
      def print_summary(jobs, io = $stdout)
        summary = Bookie::Summary::summary(jobs)
        field_labels = [
          "Number of jobs",
          "Total wall time",
          "Total CPU time",
          "% Successful",
          "Available CPU time",
          "% CPU time used",
        ]
        field_values = [
          summary[:jobs],
          Client.format_duration(summary[:wall_time]),
          Client.format_duration(summary[:cpu_time]),
          '%.2f' % (summary[:success] * 100),
          Client.format_duration(summary[:total_cpu_time]),
          '%.2f' % (summary[:used_cpu_time] * 100),
        ]
        case io
          #To do: list filters on sheet?
          when Spreadsheet::Workbook
            s = io.create_worksheet
            s.name = "Accounting"
          when IO
            field_labels.zip(field_values) do |label, value|
              io.printf("%-20.20s%s\n", "#{label}:", value)
            end
          else
            raise ArgumentError.new("Unrecognized output object type #{io.class}")
        end
      end
      
      def print_jobs(jobs, io = $stdout)
        heading = sprintf @@FORMAT_STRING, 'User', 'Group', 'System', 'System type',
        'Start time', 'End time', 'Wall time', 'CPU time', 'Memory usage', 'Exit code'
        io.write heading
        io.puts '-' * (heading.length - 1)
        jobs.find_each do |job|
          system = job.system
          #To do: optimize accesses to fields that would spin off a query?
          system_type = system.system_type
          memory_stat_type = system_type.memory_stat_type
          if memory_stat_type == :unknown
            memory_stat_type = nil
          else
            memory_stat_type = "(#{memory_stat_type})"
          end
          io.printf @@FORMAT_STRING,
            job.user.name,
            job.user.group.name,
            system.name,
            system_type.name,
            job.start_time,
            job.end_time,
            Client.format_duration(job.end_time - job.start_time),
            Client.format_duration(job.cpu_time),
            "#{job.memory}kb #{memory_stat_type}",
            job.exit_code
        end
      end
      
      #To do: settle on a character and remove the gsub.
      @@FORMAT_STRING = "|%-15.15s|%-15.15s|%-20.20s|%-20.20s|%-26.25s|%-26.25s|%-12.10s|%-12.10s|%-20.20s|%-11.11s|\n".gsub(/\|/, " ")
      
      def self.format_duration(dur)
        dur = Integer(dur)
        hours = dur / 3600
        minutes = (dur - hours * 3600) / 60
        seconds = dur % 60
        return "#{hours.to_s.rjust(2, '0')}:#{minutes.to_s.rjust(2, '0')[0 .. 1]}:#{seconds.to_s.rjust(2, '0')[0 .. 1]}"
      end
    end
  end
end
