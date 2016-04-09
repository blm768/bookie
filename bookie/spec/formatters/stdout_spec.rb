require 'spec_helper'
require 'formatter_helper'

require 'bookie/formatters/stdout'

include FormatterHelpers

describe Bookie::Formatters::StdoutFormatter do
  let(:io_mock) { IOMock.new }
  let(:formatter) { Bookie::Formatters::StdoutFormatter.new('mock.out') }

  before(:each) do
    File.stubs(:open).returns(io_mock)
  end

  it "correctly opens files" do
    File.expects(:open).with('mock.out')
    formatter
    other_formatter = Bookie::Formatters::StdoutFormatter.new
    expect(other_formatter.instance_variable_get(:'@io')).to eql STDOUT
  end

  it "correctly formats jobs" do
    with_utc do
      #TODO: stub out the database access here?
      formatter.print_jobs(Bookie::Database::Job.order(:start_time).limit(2))
      expect(io_mock.buf).to eql <<-eos
User            System               Start time                 End time                   Wall time                      CPU time                       Memory usage         Command              Exit code
--------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
root            test1                2012-01-01 00:00:00        2012-01-01 01:00:00        0 weeks, 0 days, 01:00:00      0 weeks, 0 days, 00:01:40      200kb (avg)          vi                   0
test            test1                2012-01-01 01:00:00        2012-01-01 02:00:00        0 weeks, 0 days, 01:00:00      0 weeks, 0 days, 00:01:40      200kb (avg)          emacs                1
eos
    end
  end

  it "correctly formats summaries" do
    formatter.print_summary(FormatterHelpers::JOB_SUMMARY, FormatterHelpers::SYSTEM_CAPACITY_SUMMARY)
    expect(io_mock.buf).to eql <<-eos
Number of jobs:               40
Total CPU time:               0 weeks, 0 days, 01:06:40
Successful:                   50.0000%
Available CPU time:           0 weeks, 5 days, 20:00:00
CPU time used:                0.7937%
Available memory (average):   1750000 kb
Memory used (average):        0.0114%
eos
  end
end
