require 'bookie'

require 'date'
require 'spreadsheet'

module Bookie
  module Formatter
    class Formatter
      def initialize(config, formatter)
        @config = config
        #Needed for symbol arguments
        formatter = formatter.to_s
        require "bookie/formatters/#{formatter}"
        extend Bookie::Formatter.const_get(formatter.camelize)
      end
      
      SUMMARY_FIELD_LABELS = [
          "Number of jobs",
          "Total wall time",
          "Total CPU time",
          "% Successful",
          "Available CPU time",
          "% CPU time used",
          "Available memory (average)",
          "% memory used (average)",
        ]
        DETAILS_FIELD_LABELS = [
          'User', 'Group', 'System', 'System type', 'Start time', 'End time', 'Wall time',
          'CPU time', 'Memory usage', 'Exit code'
        ]
      
      def print_summary(jobs, io, start_time = nil, end_time = nil)
        jobs_summary = jobs.summary(start_time, end_time)
        systems_summary = Bookie::Database::System.summary(start_time, end_time)
        cpu_time = jobs_summary[:cpu_time]
        avail_cpu_time = systems_summary[:avail_cpu_time]
        memory_time = jobs_summary[:memory_time]
        avail_memory_time = systems_summary[:avail_memory_time]
        field_values = [
          jobs_summary[:jobs],
          Formatter.format_duration(jobs_summary[:wall_time]),
          Formatter.format_duration(cpu_time),
          jobs_summary[:successful] * 100,
          Formatter.format_duration(systems_summary[:avail_cpu_time]),
          if avail_cpu_time == 0 then 0.0 else Float(cpu_time) / avail_cpu_time * 100 end,
          nil,
          if avail_memory_time == 0 then 0.0 else Float(memory_time) / avail_memory_time * 100 end
        ]
        do_print_summary(field_values, io)
      end
      
      def print_jobs(jobs, io)
        do_print_jobs(jobs, io)
      end
      
      def print_non_response_warnings(io)
        do_print_non_response_warnings(Bookie::Database::System, io)
      end
      
      def each_non_response_warning(systems)
        systems.active_systems.all.each do |system|
          job = Bookie::Database::Job.where('system_id = ?', system.id).order('end_time DESC').first
          if job == nil
            yield system.name, "No jobs on record"
          elsif Time.now - job.end_time > @config.maximum_idle * 3600 * 24
            yield system.name, "No jobs on record since #{job.end_time.getlocal.to_date}"
          end
        end
      end
      
      def fields_for_each_job(jobs)
        jobs.each_with_relations do |job|
          #To do: optimize?
          memory_stat_type = job.system.system_type.memory_stat_type
          if memory_stat_type == :unknown
            memory_stat_type = ''
          else
            memory_stat_type = " (#{memory_stat_type})"
          end
          yield [
            job.user.name,
            job.user.group.name,
            job.system.name,
            job.system.system_type.name,
            job.start_time.getlocal.strftime('%Y-%m-%d %H:%M:%S'),
            job.end_time.getlocal.strftime('%Y-%m-%d %H:%M:%S'),
            Formatter.format_duration(job.end_time - job.start_time),
            Formatter.format_duration(job.cpu_time),
            "#{job.memory}kb#{memory_stat_type}",
            job.exit_code
          ]
        end
      end
      protected :fields_for_each_job
      
      FORMAT_STRING = "%-15.15s %-15.15s %-20.20s %-20.20s %-26.25s %-26.25s %-12.10s %-12.10s %-20.20s %-11.11s\n"
      
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
