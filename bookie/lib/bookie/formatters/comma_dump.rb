module Bookie::Formatters
  ##
  #Formats data as a CSV file
  class CommaDumpFormatter
    FORMATTER_TYPE = :comma_dump
    include Formatter

    def initialize(filename)
      @file = File.open(filename)
    end

    def print_summary(job_summary, system_capacity_summary)
      field_values = summary_field_values(job_summary, system_capacity_summary)
      Bookie::Formatter::SUMMARY_FIELD_LABELS.zip(field_values) do |label, value|
        @file.puts "#{self.class.quote(label)}, #{self.class.quote(value)}"
      end
    end

    def print_jobs(jobs)
      @file.puts Bookie::Formatter::DETAILS_FIELD_LABELS.join(', ')
      fields_for_each_job(jobs) do |fields|
        @file.puts fields.map{ |s| self.class.quote(s) }.join(', ')
      end
    end

    ##
    #Quotes a value for use as a CSV element
    def self.quote(val)
      %{"#{val.to_s.gsub('"', '""')}"}
    end
  end
end
