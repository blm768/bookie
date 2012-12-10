require 'spreadsheet'

module Bookie
  module Formatters
    module Spreadsheet
      def open(filename)
        @filename = filename
        @workbook = ::Spreadsheet::Workbook.new
      end
      
      #Actual printing is delayed until object finalization due to the workings of the Spreadsheet gem.
      def do_print_summary(field_values)
        s = @workbook.worksheet("Summary") || @workbook.create_worksheet(:name => "Summary")
        
        s.column(0).width = 20
        Formatter::SUMMARY_FIELD_LABELS.each_with_index do |value, index|
          row = s.row(index) 
          row[0] = value
          row[1] = field_values[index]
        end
      end
      
      def do_print_jobs(jobs)
        s = @workbook.worksheet("Details") || @workbook.create_worksheet(:name => "Details")
        
        s.row(0).concat(Formatter::DETAILS_FIELD_LABELS)
        (0 .. (Formatter::DETAILS_FIELD_LABELS.length - 1)).step do |i|
          s.column(i).width = 20
        end
        
        index = 1
        fields_for_each_job(jobs) do |fields|
          s.row(index).concat(fields)
          index += 1
        end
      end
      
      def do_flush()
        @workbook.write(@filename)
      end
    end
  end
end