module Bookie
  module Client
    module CommaDump
      def do_print_summary(field_values, file)
        Client::SUMMARY_FIELD_LABELS.zip(field_values) do |label, value|
          if value.class == Float
            value = '%.2f' % value
            value << "%" if label[0] == "%"
          end
          file.puts "#{label}, #{value}"
        end
      end
      
      def do_print_jobs(jobs, file)
        file.puts Client::DETAILS_FIELD_LABELS.join(', ')
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