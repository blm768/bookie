require 'spec_helper'

describe Bookie::Formatter::Formatter do
  before(:all) do
    Bookie::Database::create_tables
    Helpers::generate_database
    Bookie::Formatter::Formatter.any_instance.stubs(:require)
    Bookie::Formatter::Formatter.any_instance.stubs(:extend)
    @sender = Bookie::Formatter::Formatter.new(@config, :formatter)
  end
  
  after(:all) do
    FileUtils.rm('spec/test.sqlite')
  end
  
  it "correctly formats durations" do
    Bookie::Formatter::Formatter.format_duration(3600 * 6 + 60 * 5 + 4).should eql '06:05:04'
  end
  
  it "correctly calculates fields for jobs" do
    
  end
  
  it "prints the correct summary fields"
end
