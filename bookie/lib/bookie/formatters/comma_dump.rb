module Bookie
  module Formatters
    ##
    #Formats data as a CSV file
    module CommaDump
      def open(filename)
        @file = File.open(filename)
      end
      
      def do_print_summary(field_values)
        Formatter::SUMMARY_FIELD_LABELS.zip(field_values) do |label, value|
          #To do: handle values with embedded quotes?
          @file.puts %{"#{label}", "#{value}"}
        end
      end
      
      def do_print_jobs(jobs)
        @file.puts Formatter::DETAILS_FIELD_LABELS.join(', ')
        fields_for_each_job(jobs) do |fields|
          @file.puts fields.map{ |s| %{"#{s}"} }.join(', ')
        end
      end
    end
  end
end
