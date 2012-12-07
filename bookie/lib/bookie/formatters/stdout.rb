module Bookie
  module Formatter
    module Stdout
      def do_print_summary(field_values, out = STDOUT)
        Formatter::SUMMARY_FIELD_LABELS.zip(field_values) do |label, value|
          out.printf("%-30.30s%s\n", "#{label}:", value)
        end
      end
      
      def do_print_jobs(jobs, out = STDOUT)
        heading = sprintf Formatter::FORMAT_STRING, *Formatter::DETAILS_FIELD_LABELS
        out.write heading
        out.puts '-' * (heading.length - 1)
        fields_for_each_job(jobs) do |fields|
          out.printf Formatter::FORMAT_STRING, *fields
        end
      end
    end
  end
end
