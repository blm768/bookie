module Bookie
  module Formatter
    module Stdout
      def do_print_summary(field_values, out = STDOUT)
        Formatter::SUMMARY_FIELD_LABELS.zip(field_values) do |label, value|
          out.printf("%-30.30s%s\n", "#{label}:", value)
        end
      end
      
      def do_print_jobs(jobs, out = STDOUT)
        #To consider: optimize by moving out of the function?
        format_string = "%-15.15s %-15.15s %-20.20s %-20.20s %-26.25s %-26.25s %-12.10s %-12.10s %-20.20s %-11.11s\n"
        heading = sprintf(format_string, *Formatter::DETAILS_FIELD_LABELS)
        out.write heading
        out.puts '-' * (heading.length - 1)
        fields_for_each_job(jobs) do |fields|
          out.printf(format_string, *fields)
        end
      end
    end
  end
end
