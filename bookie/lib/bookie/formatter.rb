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
    #
    #===Examples
    #  config = Bookie::Config.new('config.json')
    #  #Uses the spreadsheet formatter from 'bookie/formatters/spreadsheet'
    #  formatter = Bookie::Formatter::Formatter.new(config, :spreadsheet)
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
      DETAILS_FIELD_LABELS = [
        'User', 'Group', 'System', 'System type', 'Start time', 'End time', 'Wall time',
        'CPU time', 'Memory usage', 'Exit code'
      ]
    
    ##
    #Prints a summary of <tt>jobs</tt> and <tt>systems</tt> to <tt>io</tt>
    #
    #Use start_time and end_time to filter the jobs by a time range.
    #
    #It is probably not a good idea to apply any time-based filters to <tt>jobs</tt> or <tt>systems</tt> beforehand.
    #
    #Both <tt>jobs</tt> and <tt>systems</tt> should be either models or ActiveRecord::Relation objects.
    #
    #Returns the summaries for <tt>jobs</tt> and <tt>systems</tt>
    def print_summary(jobs, systems, start_time = nil, end_time = nil)
      jobs_summary = jobs.summary(start_time, end_time)
      systems_summary = systems.summary(start_time, end_time)
      cpu_time = jobs_summary[:cpu_time]
      avail_cpu_time = systems_summary[:avail_cpu_time]
      memory_time = jobs_summary[:memory_time]
      avail_memory_time = systems_summary[:avail_memory_time]
      field_values = [
        jobs_summary[:jobs].length,
        Formatter.format_duration(cpu_time),
        '%.4f%%' % (jobs_summary[:successful] * 100),
        Formatter.format_duration(systems_summary[:avail_cpu_time]),
        if avail_cpu_time == 0 then '0.0000%' else '%.4f%%' % (Float(cpu_time) / avail_cpu_time * 100) end,
        "#{Integer(systems_summary[:avail_memory_avg])} kb",
        if avail_memory_time == 0 then '0.0000%' else '%.4f%%' % (Float(memory_time) / avail_memory_time * 100) end
      ]
      do_print_summary(field_values)
      return jobs_summary, systems_summary
    end
    
    ##
    #Prints a table containing all details of <tt>jobs</tt>
    #
    #<tt>jobs</tt> should be an array.
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
    #<tt>jobs</tt> should be an array of Bookie::Database::Job objects.
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
    
    ##
    #Formats a duration in HH:MM:SS format
    #
    #<tt>dur</tt> should be a number in seconds.
    def self.format_duration(dur)
      dur = Integer(dur)
      hours = dur / 3600
      minutes = (dur - hours * 3600) / 60
      seconds = dur % 60
      return "#{hours.to_s.rjust(2, '0')}:#{minutes.to_s.rjust(2, '0')[0 .. 1]}:#{seconds.to_s.rjust(2, '0')[0 .. 1]}"
    end
  end
  
  #Contains all formatter plugins
  module Formatters
    
  end
end
