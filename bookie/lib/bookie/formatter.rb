require 'bookie/database'

require 'date'

module Bookie
  ##
  #Takes jobs from the database and creates summaries and tables in various output formats.
  module Formatter
    ##
    #Gets the Formatter class corresponding to <tt>type</tt>
    #
    #<tt>type</tt> should be a symbol that maps to one of the files in <tt>bookie/formatters</tt>.
    #
    #===Examples
    #  #Uses the formatter from 'bookie/formatters/csv'
    #  formatter = Bookie::Formatter.for_type(:csv).new('test.csv')
    def self.for_type(type)
      @formatter_classes ||= {}
      type = type.to_s
      require "bookie/formatters/#{type}"
      @formatter_classes[type]
    end

    def self.included(klass)
      @formatter_classes ||= {}
      @formatter_classes[klass.const_get(:FORMATTER_TYPE)] = klass
    end

    ##
    #An array containing the labels for each field in a summary
    SUMMARY_FIELD_LABELS = [
      'Number of jobs',
      'Total CPU time',
      'Successful',
      'Available CPU time',
      'CPU time used',
      'Available memory (average)',
      'Memory used (average)',
    ]

    ##
    #An array containing the labels for each field in a details table
    #TODO: remove some fields?
    DETAILS_FIELD_LABELS = [
      'User', 'System', 'Start time', 'End time', 'Wall time',
      'CPU time', 'Memory usage', 'Command', 'Exit code'
    ]

    ##
    #Returns an array containing the values corresponding to the labels in SUMMARY_FIELD_LABELS
    def summary_field_values(job_summary, system_capacity_summary)
      num_jobs = job_summary[:num_jobs]
      cpu_time = job_summary[:cpu_time]
      avail_cpu_time = system_capacity_summary[:avail_cpu_time]
      memory_time = job_summary[:memory_time]
      avail_memory_time = system_capacity_summary[:avail_memory_time]
      successful = (num_jobs == 0) ? 0.0 : Float(job_summary[:successful]) / num_jobs

      [
        num_jobs,
        Formatter.format_duration(cpu_time),
        '%.4f%%' % (successful * 100),
        Formatter.format_duration(avail_cpu_time),
        if avail_cpu_time == 0 then '0.0000%' else '%.4f%%' % (Float(cpu_time) / avail_cpu_time * 100) end,
        "#{Integer(system_capacity_summary[:avail_memory_avg])} kb",
        if avail_memory_time == 0 then '0.0000%' else '%.4f%%' % (Float(memory_time) / avail_memory_time * 100) end
      ]
    end

    ##
    #For each job, yields an array containing the field values to be used when printing a table of jobs
    #
    #call-seq:
    #  fields_for_each_job(jobs) { |fields| ... }
    #
    #===Examples
    #  formatter.fields_for_each_job(jobs) do |fields|
    #    Bookie::Formatter::DETAILS_FIELD_LABELS.zip(fields) do |label, field|
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
