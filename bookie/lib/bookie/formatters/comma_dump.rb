module Bookie
  module Formatters
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
    end
  end
end