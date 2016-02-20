require 'spec_helper'
require 'formatter_helper'

#TODO: move into a helper module?
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
  let(:capacities) { Database::SystemCapacity }

  it "loads the formatter code" do
    Formatter.any_instance.expects(:require).with('bookie/formatters/mock')
    Formatter.new(:mock)
  end

  it "correctly formats durations" do
    expect(Formatter.format_duration(1.seconds + 2.minutes + 3.hours + 4.days + 5.weeks)).to eql '5 weeks, 4 days, 03:02:01'
    expect(Formatter.format_duration(1.weeks + 1.days)).to eql '1 week, 1 day, 00:00:00'
  end

  it "correctly calculates fields for jobs" do
    with_utc do
      formatter.fields_for_each_job(jobs.limit(1)) do |fields|
        expect(fields).to eql [
            'root',
            'test1',
            '2012-01-01 00:00:00',
            '2012-01-01 01:00:00',
            '0 weeks, 0 days, 01:00:00',
            '0 weeks, 0 days, 00:01:40',
            '200kb (avg)',
            'vi',
            0,
          ]
      end

      #Check a different memory stat type.
      jobs = [Database::Job.first]
      jobs[0].system.system_type.memory_stat_type = :unknown
      formatter.send(:fields_for_each_job, jobs) do |fields|
        expect(fields[6]).to eql '200kb'
      end
    end
  end

  describe "#print_summary" do
    #TODO: break into contexts
    it "prints the correct summary fields" do
      with_utc do
        formatter.print_summary(FormatterHelpers::JOB_SUMMARY, FormatterHelpers::SYSTEM_CAPACITY_SUMMARY)
        formatter.flush
        expect(formatter.mock_field_values).to eql [
          40, "0 weeks, 0 days, 01:06:40", "50.0000%",
          "0 weeks, 5 days, 20:00:00", "0.7937%",
          "1750000 kb", "0.0114%"
        ]

        formatter.print_summary(FormatterHelpers::JOB_SUMMARY_EMPTY, FormatterHelpers::SYSTEM_CAPACITY_SUMMARY_EMPTY)
        formatter.flush
        expect(formatter.mock_field_values).to eql [
          0, "0 weeks, 0 days, 00:00:00", "0.0000%",
          "0 weeks, 0 days, 00:00:00", "0.0000%",
          "0 kb", "0.0000%"
        ]
      end
    end
  end

  it "forwards print_jobs to do_print_jobs" do
    formatter.expects(:do_print_jobs).with(Job)
    formatter.print_jobs(Job)
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
