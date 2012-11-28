module Bookie
  module Formatter
    module Spreadsheet
      def do_print_summary(field_values, workbook)
        s = workbook.worksheet("Summary") || workbook.create_worksheet(:name => "Summary")
          
        start = s.last_row_index
        start += 2 if start > 0
        s.column(0).width = 20
        Formatter::SUMMARY_FIELD_LABELS.each_with_index do |value, index|
          row = s.row(start + index) 
          row[0] = value
          row[1] = field_values[index]
        end
      end
      
      def do_print_jobs(jobs, workbook)
        s = workbook.worksheet("Details") || workbook.create_worksheet(:name => "Details")
            
        start = s.last_row_index
        start += 2 if start > 0
        #s.column(0).width = 20
        s.row(start).concat(Formatter::DETAILS_FIELD_LABELS)
        (0 .. (Formatter::DETAILS_FIELD_LABELS.length - 1)).step do |i|
          s.column(i).width = 20
        end
        
        index = start + 1
        fields_for_each_job(jobs) do |fields|
          s.row(index).concat(fields)
          index += 1
        end
      end
      
      def do_print_non_response_warnings(systems, workbook)
        s = workbook.worksheet("Warnings") || workbook.create_worksheet(:name => "Warnings")
            
        start = s.last_row_index
        start += 2 if start > 0
        
        index = start + 1
        each_non_response_warning(systems) do |system_name, warning|
          s.row(index).concat([system_name, warning])
          ++index
        end
      end
    end
  end
end