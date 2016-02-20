require 'spec_helper'
require 'formatter_helper'

require 'bookie/formatters/spreadsheet'

include Bookie
include Bookie::Database

class MockWorkbook
  def initialize
    @worksheets = {}
  end

  def worksheet(name)
    @worksheets[name] ||= MockWorksheet.new
  end
end

class MockWorksheet
  attr_reader :mock_rows
  attr_reader :mock_columns

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
  let(:mock_workbook) { MockWorkbook.new }
  before(:each) do
    Spreadsheet::Workbook.expects(:new).returns(mock_workbook)
  end
  let(:formatter) { Bookie::Formatter.new(:spreadsheet, 'test.xls') }

  it "correctly formats jobs" do
    with_utc do
      formatter.print_jobs(Job.limit(2))
      w = mock_workbook.worksheet('Details')
      expect(w.mock_columns.length).to eql Bookie::Formatter::DETAILS_FIELD_LABELS.length
      w.mock_columns.each do |col|
        expect(col.width).to_not eql nil
      end
      expect(w.mock_rows).to eql([
        Bookie::Formatter::DETAILS_FIELD_LABELS,
        [
          "root", "test1", "2012-01-01 00:00:00", "2012-01-01 01:00:00",
          "0 weeks, 0 days, 01:00:00", "0 weeks, 0 days, 00:01:40", "200kb (avg)", 'vi', 0
        ],
        ["test", "test1", "2012-01-01 01:00:00", "2012-01-01 02:00:00",
         "0 weeks, 0 days, 01:00:00", "0 weeks, 0 days, 00:01:40", "200kb (avg)", 'emacs', 1
        ],
      ])
    end
  end

  it "correctly formats summaries" do
    formatter.print_summary(FormatterHelpers::JOB_SUMMARY, FormatterHelpers::SYSTEM_CAPACITY_SUMMARY)
    w = mock_workbook.worksheet('Summary')
    expect(w.column(0).width).to_not eql nil
    expect(w.mock_rows).to eql([
      ["Number of jobs", 40],
      ["Total CPU time", "0 weeks, 0 days, 01:06:40"],
      ["Successful", "50.0000%"],
      ["Available CPU time", "0 weeks, 5 days, 20:00:00"],
      ["CPU time used", "0.7937%"],
      ["Available memory (average)", "1750000 kb"],
      ["Memory used (average)", "0.0114%"],
    ])
  end

  it "correctly flushes output" do
    mock_workbook.expects(:write).with('test.xls')
    formatter.do_flush
  end
end
