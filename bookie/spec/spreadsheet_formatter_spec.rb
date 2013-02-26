require 'spec_helper'

module Bookie
  module Formatters
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
  
  def mock_rows
    @mock_rows
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

describe Bookie::Formatters::Spreadsheet do
  before(:all) do
    Bookie::Database::Migration.up
    Helpers::generate_database
    @jobs = Bookie::Database::Job
  end
  
  before(:each) do
    @m = MockWorkbook.new
    Spreadsheet::Workbook.expects(:new).returns(@m)
    @formatter = Bookie::Formatter.new(:spreadsheet, 'test.xls')
  end
  
  after(:all) do
    FileUtils.rm('test.sqlite')
  end
  
  it "correctly formats jobs" do
    @formatter.print_jobs(@jobs.limit(2))
    w = @m.worksheet('Details')
    w.last_row_index.should eql 2
    w.mock_columns.length.should eql Bookie::Formatter::DETAILS_FIELD_LABELS.length
    w.mock_columns.each do |col|
      col.width.should_not eql nil
    end
    w.row(0).should eql Bookie::Formatter::DETAILS_FIELD_LABELS
    w.row(1).should eql ["root", "root", "test1", "Standalone", "2012-01-01 00:00:00",
      "2012-01-01 01:00:00", "01:00:00", "00:01:40", "200kb (avg)", 0]
    w.row(2).should eql ["test", "default", "test1", "Standalone", "2012-01-01 01:00:00",
      "2012-01-01 02:00:00", "01:00:00", "00:01:40", "200kb (avg)", 1]
  end
  
  it "correctly formats summaries" do
    Time.expects(:now).returns(Time.local(2012) + 3600 * 40).at_least_once
    @formatter.print_summary(@jobs.order(:start_time).limit(5), Bookie::Database::System)
    w = @m.worksheet('Summary')
    w.column(0).width.should_not eql nil
    w.last_row_index.should eql 6
    w.mock_rows.should eql [
      ["Number of jobs", 5],
      ["Total CPU time", "00:08:20"],
      ["Successful", "60.0000%"],
      ["Available CPU time", "140:00:00"],
      ["CPU time used", "0.0992%"],
      ["Available memory (average)", "1750000 kb"],
      ["Memory used (average)", "0.0014%"],
    ]
  end
  
  it "correctly flushes output" do
    @m.expects(:write).with('test.xls')
    @formatter.do_flush
  end
end
