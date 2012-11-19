module Bookie
  module Client
    module Stdout
      def do_print_summary(field_values, out = STDOUT)
        Client::SUMMARY_FIELD_LABELS.zip(field_values) do |label, value|
          if value.class == Float
            value = '%.2f' % value
            value << "%" if label[0] == "%"
          end
          out.printf("%-20.20s%s\n", "#{label}:", value)
        end
      end
      
      def do_print_jobs(jobs, out = STDOUT)
        heading = sprintf Client::FORMAT_STRING, *Client::DETAILS_FIELD_LABELS
        out.write heading
        out.puts '-' * (heading.length - 1)
        fields_for_each_job(jobs) do |fields|
          out.printf Client::FORMAT_STRING, *fields
        end
      end
      
      def do_print_non_response_warnings(systems, out = STDOUT)
        each_non_response_warning(systems) do |system_name, warning|
          out.puts "Warning: #{warning} for #{system_name}"
        end
      end
    end
  end
end
