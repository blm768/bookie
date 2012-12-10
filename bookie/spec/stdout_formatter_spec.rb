require 'spec_helper'

module Bookie
  module Formatters
    module Stdout
    
    end
  end
end

describe Bookie::Formatters::Stdout do
  before(:all) do
    Bookie::Database::Migration.up
    Helpers::generate_database
    @jobs = Bookie::Database::Job
  end
  
  before(:each) do
    @m = IOMock.new
    File.expects(:open).returns(@m)
    @formatter = Bookie::Formatter.new(:stdout, 'mock.out')
  end
  
  after(:all) do
    FileUtils.rm('test.sqlite')
  end
  
  it "correctly opens files" do
    f = Bookie::Formatter.new(:stdout)
    f.instance_variable_get(:'@io').should eql STDOUT
    File.expects(:open).with('mock.out')
    f = Bookie::Formatter.new(:stdout, 'mock.out')
  end
  
  it "correctly formats jobs" do
    @formatter.print_jobs(@jobs.order(:start_time).limit(2))
    @formatter.flush
    @m.buf.should eql \
      "User            Group           System               System type          Start " +
      "time                 End time                   Wall time    CPU time     Memory" +
      " usage         Exit code  \n----------------------------------------------------" +
      "--------------------------------------------------------------------------------" +
      "------------------------------------------------------\nroot            root    " +
      "        test1                Standalone           2012-01-01 00:00:00        201" +
      "2-01-01 01:00:00        01:00:00     00:01:40     200kb (avg)          0        " +
      "  \ntest            default         test1                Standalone           20" +
      "12-01-01 01:00:00        2012-01-01 02:00:00        01:00:00     00:01:40     20" +
      "0kb (avg)          1          \n"
  end
  
  it "correctly formats summaries" do
    Time.expects(:now).returns(Time.local(2012) + 36000 * 4).at_least_once
    @formatter.print_summary(@jobs.order(:start_time).limit(5), Bookie::Database::System)
    @formatter.flush
    @m.buf.should eql <<-eos
Number of jobs:               5
Total wall time:              05:00:00
Total CPU time:               00:08:20
Successful:                   60.0000%
Available CPU time:           140:00:00
CPU time used:                0.0992%
Available memory (average):   1750000 kb
Memory used (average):        0.0014%
eos
  end
end
