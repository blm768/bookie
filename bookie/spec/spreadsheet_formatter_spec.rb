require 'spec_helper'

module Bookie
  module Formatter
    module Spreadsheet

    end
  end
end

class MockWorkbook
  def initialize
    @worksheets = {}
  end

  def worksheet(name)
    @worksheets[name] ||= MockWorksheet.new
  end
end

class MockWorksheet
  def initialize
    @mock_rows = []
    @mock_columns = []
  end

  def row(num)
    @mock_rows[num] ||= []
  end
  
  def column(num)
    @mock_columns[num] ||= MockColumn.new
  end
  
  def mock_columns
    @mock_columns
  end
  
  def last_row_index
    @mock_rows.length - 1
  end
end

class MockColumn
  def width=(value)
    @width = value
  end
  
  def width
    @width
  end
end

describe Bookie::Formatter::Spreadsheet do
  before(:all) do
    Bookie::Database::create_tables
    Helpers::generate_database
    @formatter = Bookie::Formatter::Formatter.new(@config, :spreadsheet)
    @jobs = Bookie::Database::Job
  end
  
  after(:all) do
    FileUtils.rm('spec/test.sqlite')
  end
  
  it "correctly formats jobs" do
    m = MockWorkbook.new
    @formatter.print_jobs(@jobs.limit(2), m)
    w = m.worksheet('Details')
    w.last_row_index.should eql 2
    w.mock_columns.length.should eql Bookie::Formatter::Formatter::DETAILS_FIELD_LABELS.length
    w.mock_columns.each do |col|
      col.width.should_not eql nil
    end
    w.row(0).should eql Bookie::Formatter::Formatter::DETAILS_FIELD_LABELS
    w.row(1).should eql ["root", "root", "test1", "Standalone", "2012-01-01 00:00:00",
      "2012-01-01 01:00:00", "01:00:00", "00:01:40", "1024kb (avg)", 0]
    w.row(2).should eql ["test", "default", "test1", "Standalone", "2012-01-01 01:00:00",
      "2012-01-01 02:00:00", "01:00:00", "00:01:40", "2048kb (avg)", 1]
  end
  
  it "correctly formats summaries" do
    m = MockWorkbook.new
    @formatter.print_summary(@jobs.limit(1), m)
    w = m.worksheet('Summary')
    w.last_row_index.should eql 5
    w.column(0).width.should_not eql nil
    Bookie::Formatter::Formatter::SUMMARY_FIELD_LABELS.each_with_index do |label, index|
      w.row(index)[0].should eql label
      #To do: make more specific?
      w.row(index)[1].should_not eql nil
    end
  end
  
  it "correctly formats non-response warnings" do
    m = MockWorkbook.new
    @formatter.print_non_response_warnings(m)
    w = m.worksheet('Warnings')
    w.last_row_index.should eql 2
  end
end
