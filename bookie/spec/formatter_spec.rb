require 'spec_helper'

module Bookie
  module Formatter
    module Mock
      def do_print_summary(field_values, io)
        #A bit of an ugly hack, but .should doesn't work here.
        $field_values = field_values
      end
    end
  end
end

describe Bookie::Formatter::Formatter do
  before(:all) do
    Bookie::Database::create_tables
    Helpers::generate_database
    Bookie::Formatter::Formatter.any_instance.stubs(:require)
    @formatter = Bookie::Formatter::Formatter.new(@config, :mock)
    @jobs = Bookie::Database::Job
  end
  
  after(:all) do
    FileUtils.rm('test.sqlite')
  end
  
  it "correctly formats durations" do
    Bookie::Formatter::Formatter.format_duration(3600 * 6 + 60 * 5 + 4).should eql '06:05:04'
  end
  
  it "correctly calculates fields for jobs" do
    @formatter.send(:fields_for_each_job, @jobs.limit(1)) do |fields|
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
    class JobsMock
      def self.each_with_relations
        job = Bookie::Database::Job.first
        job.system.system_type.memory_stat_type = :unknown
        yield job
      end
    end
    @formatter.send(:fields_for_each_job, JobsMock) do |fields|
      fields[8].should eql '200kb'
    end
  end
  
  it "prints the correct summary fields" do
    Time.expects(:now).returns(Time.local(2012) + 3600 * 40).at_least_once
    @formatter.print_summary(@jobs.order(:start_time).limit(5), Bookie::Database::System, nil)
    $field_values.should eql [5, "05:00:00", "00:08:20", "60.0000%", "140:00:00", "0.0992%", "1750000 kb", "0.0014%"]
    Bookie::Database::System.expects(:summary).returns(
      :avail_cpu_time => 0,
      :avail_memory_time => 0,
      :avail_memory_avg => 0
    )
    @formatter.print_summary(@jobs.limit(0), Bookie::Database::System, nil)
    $field_values.should eql [0, "00:00:00", "00:00:00", "0.0000%", "00:00:00", "0.0000%", "0 kb", "0.0000%"]
  end
  
  it "forwards print_jobs to do_print_jobs" do
    @formatter.expects(:do_print_jobs)
    @formatter.print_jobs(nil, nil)
  end
end
