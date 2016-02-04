require 'spec_helper'

require 'bookie/formatters/comma_dump'

include Bookie
include Bookie::Database

describe Bookie::Formatters::CommaDump do
  let(:io_mock) { IOMock.new }
  before(:each) do
    File.expects(:open).at_least(0).returns(io_mock)
  end
  let(:formatter) { Bookie::Formatter.new(:comma_dump, 'test.csv') }

  it "correctly opens files" do
    File.expects(:open).with('test.csv')
    Bookie::Formatter.new(:comma_dump, 'test.csv')
  end

  it "correctly formats jobs" do
    with_utc do
      formatter.print_jobs(Job.order(:start_time).limit(2))
      expect(io_mock.buf).to eql <<-eos
User, System, Start time, End time, Wall time, CPU time, Memory usage, Command, Exit code
"root", "test1", "2012-01-01 00:00:00", "2012-01-01 01:00:00", "0 weeks, 0 days, 01:00:00", "0 weeks, 0 days, 00:01:40", "200kb (avg)", "vi", "0"
"test", "test1", "2012-01-01 01:00:00", "2012-01-01 02:00:00", "0 weeks, 0 days, 01:00:00", "0 weeks, 0 days, 00:01:40", "200kb (avg)", "emacs", "1"
eos
    end
  end

  it "correctly formats summaries" do
    Time.expects(:now).returns(base_time + 40.hours).at_least_once
    formatter.print_summary(Job, JobSummary, System)
    expect(io_mock.buf).to eql <<-eos
"Number of jobs", "40"
"Total CPU time", "0 weeks, 0 days, 01:06:40"
"Successful", "50.0000%"
"Available CPU time", "0 weeks, 5 days, 20:00:00"
"CPU time used", "0.7937%"
"Available memory (average)", "1750000 kb"
"Memory used (average)", "0.0114%"
eos
  end

  it "correctly quotes values" do
    formatter = Formatters::CommaDump
    expect(formatter.quote("test")).to eql '"test"'
    expect(formatter.quote('"test"')).to eql '"""test"""'
    expect(formatter.quote(0)).to eql '"0"'
  end
end
