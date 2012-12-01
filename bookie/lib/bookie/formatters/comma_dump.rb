module Bookie
  module Formatter
    module CommaDump
      def do_print_summary(field_values, file)
        Formatter::SUMMARY_FIELD_LABELS.zip(field_values) do |label, value|
          file.puts "#{label}, #{value}"
        end
      end
      
      def do_print_jobs(jobs, file)
        file.puts Formatter::DETAILS_FIELD_LABELS.join(', ')
        fields_for_each_job(jobs) do |fields|
          file.puts fields.join(', ')
        end
      end
      
      def do_print_non_response_warnings(systems, file)
        each_non_response_warning(systems) do |system_name, warning|
          file.puts "#{system_name}, #{warning}"
        end
      end
    end
  end
end