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
          @file.puts "#{CommaDump.quote(label)}, #{CommaDump.quote(value)}"
        end
      end
      
      def do_print_jobs(jobs)
        @file.puts Formatter::DETAILS_FIELD_LABELS.join(', ')
        fields_for_each_job(jobs) do |fields|
          @file.puts fields.map{ |s| CommaDump.quote(s) }.join(', ')
        end
      end
      
      ##
      #Quotes a value for use as a CSV element
      #To do: unit test.
      def self.quote(val)
        %{"#{val.to_s.gsub('"', '""')}"}
      end
    end
  end
end
