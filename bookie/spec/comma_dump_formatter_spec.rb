require 'spec_helper'

module Bookie
  module Formatters
    module CommaDump
    
    end
  end
end

describe Bookie::Formatters::CommaDump do
  before(:all) do
    Bookie::Database::Migration.up
    Helpers::generate_database
    @jobs = Bookie::Database::Job
  end
  
  before(:each) do
    @m = IOMock.new
    File.expects(:open).returns(@m)
    @formatter = Bookie::Formatter.new(:comma_dump, 'test.csv')
  end
  
  after(:all) do
    FileUtils.rm('test.sqlite')
  end
  
  it "correctly opens files" do
    File.expects(:open).with('test.csv')
    f = Bookie::Formatter::new(:comma_dump, 'test.csv')
  end
  
  it "correctly formats jobs" do
    @formatter.print_jobs(@jobs.order(:start_time).limit(2))
    @m.buf.should eql <<-eos
User, Group, System, System type, Start time, End time, Wall time, CPU time, Memory usage, Exit code
root, root, test1, Standalone, 2012-01-01 00:00:00, 2012-01-01 01:00:00, 01:00:00, 00:01:40, 200kb (avg), 0
test, default, test1, Standalone, 2012-01-01 01:00:00, 2012-01-01 02:00:00, 01:00:00, 00:01:40, 200kb (avg), 1
eos
  end
  
  it "correctly formats summaries" do
    Time.expects(:now).returns(Time.local(2012) + 36000 * 4).at_least_once
    @formatter.print_summary(@jobs.order(:start_time).limit(5), Bookie::Database::System)
    @m.buf.should eql <<-eos
Number of jobs, 5
Total CPU time, 00:08:20
Successful, 60.0000%
Available CPU time, 140:00:00
CPU time used, 0.0992%
Available memory (average), 1750000 kb
Memory used (average), 0.0014%
eos
  end
end
