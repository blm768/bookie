require 'bookie/database'

require 'date'
require 'spreadsheet'

module Bookie
  ##
  #Takes jobs from the database and creates summaries and tables in various output formats.
  class Formatter
    ##
    #Creates a new Formatter object
    #
    #<tt>type</tt> should be a symbol that maps to one of the files in <tt>bookie/formatters</tt>.
    #TODO: just take the formatter module directly?
    #
    #===Examples
    #  #Uses the spreadsheet formatter from 'bookie/formatters/spreadsheet'
    #  formatter = Bookie::Formatter::Formatter.new(:spreadsheet, 'test.xls')
    def initialize(type, filename = nil)
      #Needed for symbol arguments
      type = type.to_s
      require "bookie/formatters/#{type}"
      extend Bookie::Formatters.const_get(type.camelize)
      self.open(filename)
    end

    ##
    #An array containing the labels for each field in a summary
    SUMMARY_FIELD_LABELS = [
        "Number of jobs",
        "Total CPU time",
        "Successful",
        "Available CPU time",
        "CPU time used",
        "Available memory (average)",
        "Memory used (average)",
      ]

      ##
      #An array containing the labels for each field in a details table
      #TODO: remove some fields?
      DETAILS_FIELD_LABELS = [
        'User', 'System', 'Start time', 'End time', 'Wall time',
        'CPU time', 'Memory usage', 'Command', 'Exit code'
      ]

    ##
    #Prints a summary of <tt>jobs</tt> and <tt>system_capacities</tt> to using cached data
    #from <tt>summaries</tt> during the given time_range
    #
    #It is probably not a good idea to apply any time-based filters to the arguments beforehand.
    #
    #Returns the summaries for <tt>jobs</tt> and <tt>system_capacities</tt>
    def print_summary(jobs, summaries, system_capacities, time_range = nil)
      jobs_summary = summaries.summary(:jobs => jobs, :range => time_range)
      num_jobs = jobs_summary[:num_jobs]
      caps_summary = system_capacities.summary(time_range)
      cpu_time = jobs_summary[:cpu_time]
      avail_cpu_time = caps_summary[:avail_cpu_time]
      memory_time = jobs_summary[:memory_time]
      avail_memory_time = caps_summary[:avail_memory_time]
      successful = (num_jobs == 0) ? 0.0 : Float(jobs_summary[:successful]) / num_jobs

      field_values = [
        num_jobs,
        Formatter.format_duration(cpu_time),
        '%.4f%%' % (successful * 100),
        Formatter.format_duration(caps_summary[:avail_cpu_time]),
        if avail_cpu_time == 0 then '0.0000%' else '%.4f%%' % (Float(cpu_time) / avail_cpu_time * 100) end,
        "#{Integer(caps_summary[:avail_memory_avg])} kb",
        if avail_memory_time == 0 then '0.0000%' else '%.4f%%' % (Float(memory_time) / avail_memory_time * 100) end
      ]
      do_print_summary(field_values)
    end

    ##
    #Prints a table containing all details of <tt>jobs</tt>
    #
    #<tt>jobs</tt> should be an ActiveRecord model or relation.
    #
    #To consider: allow any Enumerable?
    def print_jobs(jobs)
      do_print_jobs(jobs)
    end

    ##
    #Flushes all output
    #
    #Should always be called after the desired information has been written
    def flush()
      do_flush() if self.respond_to?(:do_flush)
    end

    ##
    #For each job, yields an array containing the field values to be used when printing a table of jobs
    #
    #call-seq:
    #  fields_for_each_job(jobs) { |fields| ... }
    #
    #<tt>jobs</tt> should be an ActiveRecord model or relation.
    #
    #===Examples
    #  formatter.fields_for_each_job(jobs) do |fields|
    #    Bookie::Formatter::Formatter::DETAILS_FIELD_LABELS.zip(fields) do |label, field|
    #      puts "#{label}: #{field}"
    #    end
    #  end
    def fields_for_each_job(jobs)
      jobs.each do |job|
        memory_stat_type = job.system.system_type.memory_stat_type
        if memory_stat_type == :unknown
          memory_stat_type = ''
        else
          memory_stat_type = " (#{memory_stat_type})"
        end
        yield [
          job.user.name,
          job.system.name,
          job.start_time.getlocal.strftime('%Y-%m-%d %H:%M:%S'),
          job.end_time.getlocal.strftime('%Y-%m-%d %H:%M:%S'),
          Formatter.format_duration(job.end_time.to_i - job.start_time.to_i),
          Formatter.format_duration(job.cpu_time),
          "#{job.memory}kb#{memory_stat_type}",
          job.command_name,
          job.exit_code
        ]
      end
    end

    ##
    #Formats a duration in a human-readable format
    #
    #<tt>dur</tt> should be an integer representing the number of seconds.
    def self.format_duration(dur)
      dur = dur.to_i
      days = dur / (3600 * 24)
      dur -= days * (3600 * 24)
      hours = dur / 3600
      dur -= hours * 3600
      minutes = dur / 60
      dur -= minutes * 60
      seconds = dur

      weeks = days / 7
      days = days % 7

      "%i week%s, %i day%s, %02i:%02i:%02i" % [weeks, weeks == 1 ? '' : 's', days, days == 1 ? '' : 's', hours, minutes, seconds]
    end
  end

  #Contains all formatter plugins
  module Formatters

  end
end
