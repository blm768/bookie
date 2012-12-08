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
    @formatter = Bookie::Formatter.new(@config, :stdout)
    @jobs = Bookie::Database::Job
  end
  
  after(:all) do
    FileUtils.rm('test.sqlite')
  end
  
  it "correctly formats jobs" do
    m = IOMock.new
    @formatter.print_jobs(@jobs.order(:start_time).limit(2), m)
    m.buf.should eql \
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
    m = IOMock.new
    Time.expects(:now).returns(Time.local(2012) + 36000 * 4).at_least_once
    @formatter.print_summary(@jobs.order(:start_time).limit(5), Bookie::Database::System, m)
    m.buf.should eql <<-eos
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
