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
    @summaries = Bookie::Database::JobSummary
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
    with_utc do
      @formatter.print_jobs(@jobs.order(:start_time).limit(2).all)
      @m.buf.should eql <<-eos
User, Group, System, System type, Start time, End time, Wall time, CPU time, Memory usage, Command, Exit code
"root", "root", "test1", "Standalone", "2012-01-01 00:00:00", "2012-01-01 01:00:00", "0 weeks, 0 days, 01:00:00", "0 weeks, 0 days, 00:01:40", "200kb (avg)", "vi", "0"
"test", "default", "test1", "Standalone", "2012-01-01 01:00:00", "2012-01-01 02:00:00", "0 weeks, 0 days, 01:00:00", "0 weeks, 0 days, 00:01:40", "200kb (avg)", "emacs", "1"
eos
    end
  end
  
  it "correctly formats summaries" do
    Time.expects(:now).returns(Time.utc(2012) + 36000 * 4).at_least_once
    @formatter.print_summary(@jobs, @summaries, Bookie::Database::System)
    @m.buf.should eql <<-eos
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
    Formatter = Bookie::Formatters::CommaDump
    Formatter.quote("test").should eql '"test"'
    Formatter.quote('"test"').should eql '"""test"""'
    Formatter.quote(0).should eql '"0"'
  end
end
