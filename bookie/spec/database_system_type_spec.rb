require 'spec_helper'

include Bookie::Database

describe Bookie::Database::SystemType do
  it "correctly maps memory stat type codes to/from symbols" do
    systype = SystemType.new
    #TODO: create custom RSpec matcher for this?
    systype.memory_stat_type = :unknown
    systype.memory_stat_type.should eql :unknown
    systype.read_attribute(:memory_stat_type).should eql SystemType::MEMORY_STAT_TYPE[:unknown]
    systype.memory_stat_type = :avg
    systype.memory_stat_type.should eql :avg
    systype.read_attribute(:memory_stat_type).should eql SystemType::MEMORY_STAT_TYPE[:avg]
    systype.memory_stat_type = :max
    systype.memory_stat_type.should eql :max
    systype.read_attribute(:memory_stat_type).should eql SystemType::MEMORY_STAT_TYPE[:max]
  end
  
  it "rejects unrecognized memory stat type codes" do
    systype = SystemType.new
    expect { systype.memory_stat_type = :invalid_type }.to raise_error("Unrecognized memory stat type 'invalid_type'")
    expect { systype.memory_stat_type = nil }.to raise_error 'Memory stat type must not be nil'
    systype.send(:write_attribute, :memory_stat_type, 10000)
    expect { systype.memory_stat_type }.to raise_error("Unrecognized memory stat type code 10000")
  end
  
  it "creates the system type when needed" do
    SystemType.expects(:'create!')
    SystemType.find_or_create!('test', :avg)
  end
  
  it "raises an error if the existing type has the wrong memory stat type" do
    systype = SystemType.create!(:name => 'test', :memory_stat_type => :max)
    begin
      expect {
        SystemType.find_or_create!('test', :avg)
      }.to raise_error("The recorded memory stat type for system type 'test' does not match the required type of 1")
      expect {
        SystemType.find_or_create!('test', :unrecognized)
      }.to raise_error("Unrecognized memory stat type 'unrecognized'")
    ensure
      systype.delete
    end
  end
  
  it "uses the existing type" do
    systype = SystemType.create!(:name => 'test', :memory_stat_type => :avg)
    begin
      SystemType.expects(:'create!').never
      SystemType.find_or_create!('test', :avg)
    ensure
      systype.delete
    end
  end
  
  it "validates fields" do
    systype = SystemType.new(:name => 'test')
    expect { systype.valid? }.to raise_error('Memory stat type must not be nil')
    systype.memory_stat_type = :unknown
    systype.valid?.should eql true
    systype.name = nil
    systype.valid?.should eql false
    systype.name = ''
    systype.valid?.should eql false
  end
end

