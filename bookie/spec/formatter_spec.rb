require 'spec_helper'

module Bookie
  module Formatter
    class Mock
    
    end
  end
end

describe Bookie::Formatter::Formatter do
  before(:all) do
    Bookie::Database::create_tables
    Helpers::generate_database
    Bookie::Formatter::Formatter.any_instance.stubs(:require)
    Bookie::Formatter::Formatter.any_instance.stubs(:extend)
    @formatter = Bookie::Formatter::Formatter.new(@config, :mock)
    @jobs = Bookie::Database::Job
  end
  
  after(:all) do
    FileUtils.rm('spec/test.sqlite')
  end
  
  it "correctly formats durations" do
    Bookie::Formatter::Formatter.format_duration(3600 * 6 + 60 * 5 + 4).should eql '06:05:04'
  end
  
  it "correctly calculates fields for jobs" do
    begin
    @formatter.send(:fields_for_each_job, @jobs.limit(1)) do |fields|
      fields.should eql [
          'root',
          'root',
          'test1',
          'Standalone',
          Time.local(2012),
          Time.local(2012) + 3600,
          "01:00:00",
          "00:01:40",
          "1024kb (avg)",
          0,
        ]
    end
    rescue => e
    raise e.message + "\n" + e.backtrace.join("\n")
    end
  end
  
  it "prints the correct summary fields"
end
