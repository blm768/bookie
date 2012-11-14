require 'bookie'

require 'date'
require 'spreadsheet'

module Bookie
  module Client
    #Represents a client that can pull data from the server and display tables
    class Client
      def initialize(config, formatter)
        @config = config
        require "bookie-client/formatters/#{formatter}"
        extend Bookie::Client.const_get(formatter.to_s.camelize)
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
      
      def print_summary(jobs, io)
        summary = Bookie::Summary::summary(jobs)
        field_values = [
          summary[:jobs],
          Client.format_duration(summary[:wall_time]),
          Client.format_duration(summary[:cpu_time]),
          summary[:success] * 100,
          Client.format_duration(summary[:total_cpu_time]),
          summary[:used_cpu_time] * 100,
        ]
        do_print_summary(field_values, io)
      end
      
      def print_jobs(jobs, io)
        do_print_jobs(jobs, io)
      end
      
      def print_non_response_warnings(io)
        systems = Bookie::Database::System.where('end_time IS NULL')
        do_print_non_response_warnings(systems, io)
      end
      
      def each_non_response_warning(systems)
        systems.find_each do |system|
          job = Bookie::Database::Job.where('system_id = ?', system.id).order('end_time DESC').first
          if job == nil
            yield system.name, "No jobs on record"
          elsif Time.now - job.end_time > @config.maximum_idle * 3600 * 24
            yield system.name, "No jobs on record since #{job.end_time.to_date}"
          end
        end
      end
      
      def fields_for_each_job(jobs)
        jobs.each_with_relations do |job|
          #To do: optimize?
          memory_stat_type = job.system.system_type.memory_stat_type
          if memory_stat_type == :unknown
            memory_stat_type = nil
          else
            memory_stat_type = "(#{memory_stat_type})"
          end
          yield [
            job.user.name,
            job.user.group.name,
            job.system.name,
            job.system.system_type.name,
            job.start_time,
            job.end_time,
            Client.format_duration(job.end_time - job.start_time),
            Client.format_duration(job.cpu_time),
            "#{job.memory}kb #{memory_stat_type}",
            job.exit_code
          ]
        end
      end
      protected :fields_for_each_job
      
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
