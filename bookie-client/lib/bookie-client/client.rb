require 'bookie'

require 'date'
require 'spreadsheet'

module Bookie
  module Client
    #Represents a client that can pull data from the server and display tables
    class Client
      def initialize(config)
        @config = config
      end
      
      SUMMARY_FIELD_LABELS = [
          "Number of jobs",
          "Total wall time",
          "Total CPU time",
          "% Successful",
          "Available CPU time",
          "% CPU time used",
        ]
        DETAILS_FIELD_LABELS = [
          'User', 'Group', 'System', 'System type', 'Start time', 'End time', 'Wall time',
          'CPU time', 'Memory usage', 'Exit code'
        ]
      
      def print_summary(jobs, io = nil)
        summary = Bookie::Summary::summary(jobs)
        field_values = [
          summary[:jobs],
          Client.format_duration(summary[:wall_time]),
          Client.format_duration(summary[:cpu_time]),
          summary[:success] * 100,
          Client.format_duration(summary[:total_cpu_time]),
          summary[:used_cpu_time] * 100,
        ]
        case io
        #To do: list filters on sheet?
        when Spreadsheet::Workbook
          s = io.worksheet("Summary") || io.create_worksheet(:name => "Summary")
          
          start = s.last_row_index
          start += 2 if start > 0
          s.column(0).width = 20
          SUMMARY_FIELD_LABELS.each_index do |index|
            row = s.row(start + index) 
            row[0] = SUMMARY_FIELD_LABELS[index]
            row[1] = field_values[index]
          end
        when nil
          SUMMARY_FIELD_LABELS.zip(field_values) do |label, value|
            if value.class == Float
              value = '%.2f' % value
            end
            $stdout.printf("%-20.20s%s\n", "#{label}:", value)
          end
        else
          raise ArgumentError.new("Unrecognized output object type #{io.class}")
        end
      end
      
      def print_jobs(jobs, io)
        case io
        when Spreadsheet::Workbook
          s = io.worksheet("Details") || io.create_worksheet(:name => "Details")
            
          start = s.last_row_index
          start += 2 if start > 0
          #s.column(0).width = 20
          s.row(start).concat(DETAILS_FIELD_LABELS)
          (0 .. (DETAILS_FIELD_LABELS.length - 1)).step do |i|
            s.column(i).width = 20
          end
          
          index = start + 1
          jobs.find_each do |job|
            system = job.system
            #To do: optimize accesses to fields that would spin off a query?
            system_type = system.system_type
            s.row(index).concat(job_fields(job, system, system_type))
            index += 1
          end
        when nil
          heading = sprintf FORMAT_STRING, *DETAILS_FIELD_LABELS
          $stdout.write heading
          $stdout.puts '-' * (heading.length - 1)
          jobs.find_each do |job|
            system = job.system
            #To do: optimize accesses to fields that would spin off a query?
            system_type = system.system_type
            $stdout.printf FORMAT_STRING, *job_fields(job, system, system_type)
          end
        end
      end
      
      def job_fields(job, system, system_type)
        #To do: optimize?
        memory_stat_type = system_type.memory_stat_type
        if memory_stat_type == :unknown
          memory_stat_type = nil
        else
          memory_stat_type = "(#{memory_stat_type})"
        end
        [
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
        ]
      end
      protected :job_fields
      
      #To do: settle on a character and remove the gsub.
      FORMAT_STRING = "|%-15.15s|%-15.15s|%-20.20s|%-20.20s|%-26.25s|%-26.25s|%-12.10s|%-12.10s|%-20.20s|%-11.11s|\n".gsub(/\|/, " ")
      
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
