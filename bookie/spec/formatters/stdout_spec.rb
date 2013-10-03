require 'spec_helper'

#Declared early so the first "describe" clause works:
module Bookie
  module Formatters
    module Stdout
    
    end
  end
end

include Bookie
include Bookie::Database

describe Bookie::Formatters::Stdout do
  let(:io_mock) { IOMock.new }
  before(:each) do
    File.expects(:open).at_least(0).returns(io_mock)
  end
  let(:formatter) { Formatter.new(:stdout, 'mock.out') }

  it "correctly opens files" do
    f = Bookie::Formatter.new(:stdout)
    f.instance_variable_get(:'@io').should eql STDOUT
    File.expects(:open).with('mock.out')
    Bookie::Formatter.new(:stdout, 'mock.out')
  end
  
  it "correctly formats jobs" do
    with_utc do
      formatter.print_jobs(Job.order(:start_time).limit(2))
      formatter.flush
      io_mock.buf.should eql <<-eos
User            Group           System               System type          Start time                 End time                   Wall time                      CPU time                       Memory usage         Command              Exit code  
---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
root            root            test1                Standalone           2012-01-01 00:00:00        2012-01-01 01:00:00        0 weeks, 0 days, 01:00:00      0 weeks, 0 days, 00:01:40      200kb (avg)          vi                   0          
test            default         test1                Standalone           2012-01-01 01:00:00        2012-01-01 02:00:00        0 weeks, 0 days, 01:00:00      0 weeks, 0 days, 00:01:40      200kb (avg)          emacs                1          
eos
    end
  end
    
  it "correctly formats summaries" do
    Time.expects(:now).returns(base_time + 40.hours).at_least_once
    formatter.print_summary(Job, JobSummary, System)
    formatter.flush
    io_mock.buf.should eql <<-eos
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
