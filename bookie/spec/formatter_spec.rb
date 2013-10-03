require 'spec_helper'

module Bookie
  module Formatters
    module Mock
      attr_reader :mock_field_values

      def open(filename)
      
      end
      
      def do_print_summary(field_values)
        @mock_field_values = field_values
      end
    end
  end
end

include Bookie

describe Bookie::Formatter do
  before(:each) do
    Formatter.any_instance.stubs(:require)
  end
  
  let(:formatter) { Formatter.new(:mock) }
  let(:jobs) { Database::Job }
  let(:summaries) { Database::JobSummary }

  it "loads the formatter code" do
    Formatter.any_instance.expects(:require).with('bookie/formatters/mock')
    Formatter.new(:mock)
  end
  
  it "correctly formats durations" do
    Formatter.format_duration(1.seconds + 2.minutes + 3.hours + 4.days + 5.weeks).should eql '5 weeks, 4 days, 03:02:01'
    Formatter.format_duration(1.weeks + 1.days).should eql '1 week, 1 day, 00:00:00'
  end
  
  it "correctly calculates fields for jobs" do
    with_utc do
      formatter.send(:fields_for_each_job, jobs.limit(1).to_a) do |fields|
        fields.should eql [
            'root',
            'root',
            'test1',
            'Standalone',
            '2012-01-01 00:00:00',
            '2012-01-01 01:00:00',
            '0 weeks, 0 days, 01:00:00',
            '0 weeks, 0 days, 00:01:40',
            '200kb (avg)',
            'vi',
            0,
          ]
      end
      jobs = [Database::Job.first]
      jobs[0].system.system_type.memory_stat_type = :unknown
      formatter.send(:fields_for_each_job, jobs) do |fields|
        fields[8].should eql '200kb'
      end
    end
  end
  
  describe "#print_summary" do
    it "prints the correct summary fields" do
      with_utc do
        Time.expects(:now).returns(base_time + 40.hours).at_least_once

        formatter.print_summary(jobs, summaries, Database::System)
        formatter.flush
        formatter.mock_field_values.should eql [
          40, "0 weeks, 0 days, 01:06:40", "50.0000%",
          "0 weeks, 5 days, 20:00:00", "0.7937%",
          "1750000 kb", "0.0114%"
        ]
        
        Database::System.expects(:summary).returns(
          :avail_cpu_time => 0,
          :avail_memory_time => 0,
          :avail_memory_avg => 0
        )
        formatter.print_summary(jobs, summaries, Database::System, base_time ... base_time)
        formatter.flush
        formatter.mock_field_values.should eql [
          0, "0 weeks, 0 days, 00:00:00", "0.0000%",
          "0 weeks, 0 days, 00:00:00", "0.0000%",
          "0 kb", "0.0000%"
        ]
      end
    end
  end
  
  it "forwards print_jobs to do_print_jobs" do
    formatter.expects(:do_print_jobs)
    formatter.print_jobs(nil)
  end
  
  it "forwards flush to do_flush" do
    formatter.expects(:'respond_to?').with(:do_flush).returns(false)
    formatter.expects(:do_flush).never
    formatter.flush
    formatter.unstub(:'respond_to?')
    formatter.expects(:do_flush)
    formatter.flush
  end
end
