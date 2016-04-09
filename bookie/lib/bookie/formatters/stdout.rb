module Bookie::Formatters
  ##
  #Formats data in a human-readable text format intended to be send to standard output
  class StdoutFormatter
    FORMATTER_TYPE = :stdout
    include Bookie::Formatter

    def initialize(filename = nil)
      #TODO: manage file handles better.
      #(Leaving then to the GC is sub-optimal.)
      if filename
        @io = File.open(filename)
      else
        @io = STDOUT
      end
    end

    def print_summary(job_summary, system_capacity_summary)
      field_values = summary_field_values(job_summary, system_capacity_summary)
      Bookie::Formatter::SUMMARY_FIELD_LABELS.zip(field_values) do |label, value|
        @io.printf("%-30.30s%s\n", "#{label}:", value)
      end
    end

    def print_jobs(jobs)
      #TODO: optimize by moving out of the function?
      format_string = "%-15.15s %-20.20s %-26.26s %-26.26s %-30.30s %-30.30s %-20.20s %-20.20s %-11.11s"
      heading = sprintf(format_string, *Bookie::Formatter::DETAILS_FIELD_LABELS)
      @io.puts heading.rstrip
      @io.puts '-' * (heading.length)
      fields_for_each_job(jobs) do |fields|
        line = sprintf(format_string, *fields)
        line.rstrip!
        @io.puts line
      end
    end
  end
end
