module Bookie
  module Formatters
    ##
    #Formats data in a human-readable text format intended to be send to standard output
    module Stdout
      def open(filename)
        if filename
          @io = File.open(filename)
        else
          @io = STDOUT
        end
      end
      
      def do_print_summary(field_values)
        Formatter::SUMMARY_FIELD_LABELS.zip(field_values) do |label, value|
          @io.printf("%-30.30s%s\n", "#{label}:", value)
        end
      end
      
      def do_print_jobs(jobs)
        #To consider: optimize by moving out of the function?
        format_string = "%-15.15s %-15.15s %-20.20s %-20.20s %-26.25s %-26.25s %-12.10s %-12.10s %-20.20s %-11.11s\n"
        heading = sprintf(format_string, *Formatter::DETAILS_FIELD_LABELS)
        @io.write heading
        @io.puts '-' * (heading.length - 1)
        fields_for_each_job(jobs) do |fields|
          @io.printf(format_string, *fields)
        end
      end
    end
  end
end
