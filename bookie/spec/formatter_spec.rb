require 'spec_helper'
require 'formatter_helper'

#TODO: move into a helper module?
class MockFormatter
  FORMATTER_TYPE = :mock
  include Bookie::Formatter
end

include Bookie

describe Bookie::Formatter do
  before(:each) do
    Formatter.stubs(:require)
  end

  let(:formatter) { MockFormatter.new }
  let(:jobs) { Database::Job }
  let(:summaries) { Database::JobSummary }
  let(:capacities) { Database::SystemCapacity }

  describe "::for_type" do
    it "loads the correct formatter" do
      Formatter.expects(:require).with('bookie/formatters/mock')
      expect(Formatter.for_type(:mock)).to eql MockFormatter
    end

    it "requires the formatter to report its type" do
      expect{ Class.new { include Bookie::Formatter } }.to raise_error(NameError)
    end
  end

  describe "::format_duration" do
    it "correctly formats durations" do
      expect(Formatter.format_duration(1.seconds + 2.minutes + 3.hours + 4.days + 5.weeks)).to eql '5 weeks, 4 days, 03:02:01'
      expect(Formatter.format_duration(1.weeks + 1.days)).to eql '1 week, 1 day, 00:00:00'
    end
  end

  describe "#fields_for_each_job" do
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
  end

  describe "#summary_field_values" do
    #TODO: break into contexts
    it "prints the correct summary fields" do
      with_utc do
        fields = formatter.summary_field_values(FormatterHelpers::JOB_SUMMARY, FormatterHelpers::SYSTEM_CAPACITY_SUMMARY)
        expect(fields).to eql [
          40, "0 weeks, 0 days, 01:06:40", "50.0000%",
          "0 weeks, 5 days, 20:00:00", "0.7937%",
          "1750000 kb", "0.0114%"
        ]

        fields = formatter.summary_field_values(FormatterHelpers::JOB_SUMMARY_EMPTY, FormatterHelpers::SYSTEM_CAPACITY_SUMMARY_EMPTY)
        expect(fields).to eql [
          0, "0 weeks, 0 days, 00:00:00", "0.0000%",
          "0 weeks, 0 days, 00:00:00", "0.0000%",
          "0 kb", "0.0000%"
        ]
      end
    end
  end
end
