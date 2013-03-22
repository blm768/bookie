require 'spec_helper'

module Bookie
  module Formatters
    module Mock
      def open(filename)
      
      end
      
      def do_print_summary(field_values)
        #A bit of an ugly hack, but .should doesn't work here.
        $field_values = field_values
      end
    end
  end
end

describe Bookie::Formatter do
  before(:all) do
    Bookie::Database::Migration.up
    Helpers::generate_database
    Bookie::Formatter.any_instance.stubs(:require)
    @formatter = Bookie::Formatter.new(:mock)
    @jobs = Bookie::Database::Job
    @summaries = Bookie::Database::JobSummary
  end
  
  after(:all) do
    FileUtils.rm('test.sqlite')
  end
  
  it "correctly formats durations" do
    Bookie::Formatter.format_duration(3600 * 6 + 60 * 5 + 4).should eql '06:05:04'
  end
  
  it "correctly calculates fields for jobs" do
    @formatter.send(:fields_for_each_job, @jobs.limit(1).all) do |fields|
      fields.should eql [
          'root',
          'root',
          'test1',
          'Standalone',
          "2012-01-01 00:00:00",
          "2012-01-01 01:00:00",
          '01:00:00',
          '00:01:40',
          '200kb (avg)',
          0,
        ]
    end
    jobs = [Bookie::Database::Job.first]
    jobs[0].system.system_type.memory_stat_type = :unknown
    @formatter.send(:fields_for_each_job, jobs) do |fields|
      fields[8].should eql '200kb'
    end
  end
  
  describe "#print_summary" do
    it "prints the correct summary fields" do
      Time.expects(:now).returns(Time.local(2012) + 3600 * 40).at_least_once
      @formatter.print_summary(@jobs, @summaries, Bookie::Database::System)
      @formatter.flush
      $field_values.should eql [40, "01:06:40", "50.0000%", "140:00:00", "0.7937%", "1750000 kb", "0.0114%"]
      Bookie::Database::System.expects(:summary).returns(
        :avail_cpu_time => 0,
        :avail_memory_time => 0,
        :avail_memory_avg => 0
      )
      @formatter.print_summary(@jobs, @summaries, Bookie::Database::System, Time.local(2012) ... Time.local(2012))
      @formatter.flush
      $field_values.should eql [0, "00:00:00", "0.0000%", "00:00:00", "0.0000%", "0 kb", "0.0000%"]
    end
    
    it "returns the summary objects" do
      s1, s2 = @formatter.print_summary(@jobs, @summaries, Bookie::Database::System.limit(0))
      s1[:num_jobs].should eql 40
      s2[:avail_memory_time].should eql 0
    end
  end
  
  it "forwards print_jobs to do_print_jobs" do
    @formatter.expects(:do_print_jobs)
    @formatter.print_jobs(nil)
  end
  
  it "forwards flush to do_flush" do
    @formatter.expects(:'respond_to?').with(:do_flush).returns(false)
    @formatter.expects(:do_flush).never
    @formatter.flush
    @formatter.unstub(:'respond_to?')
    @formatter.expects(:do_flush)
    @formatter.flush
  end
end
