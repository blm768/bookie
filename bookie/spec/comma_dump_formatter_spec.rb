require 'spec_helper'

module Bookie
  module Formatter
    module CommaDump
    
    end
  end
end

describe Bookie::Formatter::CommaDump do
  before(:all) do
    Bookie::Database::create_tables
    Helpers::generate_database
    @formatter = Bookie::Formatter::Formatter.new(@config, :comma_dump)
    @jobs = Bookie::Database::Job
  end
  
  after(:all) do
    FileUtils.rm('spec/test.sqlite')
  end
  
  it "correctly formats jobs" do
    m = IOMock.new
    @formatter.print_jobs(@jobs.order(:start_time).limit(2), m)
    m.buf.should eql <<-eos
User, Group, System, System type, Start time, End time, Wall time, CPU time, Memory usage, Exit code
root, root, test1, Standalone, 2012-01-01 00:00:00, 2012-01-01 01:00:00, 01:00:00, 00:01:40, 200kb (avg), 0
test, default, test1, Standalone, 2012-01-01 01:00:00, 2012-01-01 02:00:00, 01:00:00, 00:01:40, 200kb (avg), 1
eos
  end
  
  it "correctly formats summaries" do
    m = IOMock.new
    Time.expects(:now).returns(Time.local(2012) + 36000 * 4).at_least_once
    @formatter.print_summary(@jobs.order(:start_time).limit(5), Bookie::Database::System, m)
    m.buf.should eql <<-eos
Number of jobs, 5
Total wall time, 05:00:00
Total CPU time, 00:08:20
Successful, 60.0000%
Available CPU time, 140:00:00
CPU time used, 0.0992%
Available memory (average), 1750000 kb
Memory used (average), 0.0014%
eos
  end
  
  it "correctly formats non-response warnings" do
    m = IOMock.new
    @formatter.print_non_response_warnings(m)
    m.buf.should eql <<-eos
test1, No jobs on record since 2012-01-01
test2, No jobs on record since 2012-01-02
test3, No jobs on record since 2012-01-02
eos
  end
end
