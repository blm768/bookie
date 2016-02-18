require 'spec_helper'

include Bookie::Database

describe Bookie::Database::SystemType do
  it "correctly maps memory stat type codes to/from symbols" do
    systype = SystemType.new
    #TODO: create custom RSpec matcher for this?
    systype.memory_stat_type = :unknown
    expect(systype.memory_stat_type).to eql :unknown
    expect(systype.read_attribute(:memory_stat_type)).to eql SystemType::MEMORY_STAT_TYPE[:unknown]
    systype.memory_stat_type = :avg
    expect(systype.memory_stat_type).to eql :avg
    expect(systype.read_attribute(:memory_stat_type)).to eql SystemType::MEMORY_STAT_TYPE[:avg]
    systype.memory_stat_type = :max
    expect(systype.memory_stat_type).to eql :max
    expect(systype.read_attribute(:memory_stat_type)).to eql SystemType::MEMORY_STAT_TYPE[:max]
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

  #TODO: make error messages better?
  it "raises an error if the existing type has the wrong memory stat type" do
    systype = SystemType.create!(:name => 'test', :memory_stat_type => :max)
    begin
      #TODO: create a custom error class so we don't hard-code the error message here.
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
    expect(systype.valid?).to eql false

    systype.memory_stat_type = :unknown
    expect(systype.valid?).to eql true

    [nil, ''].each do |value|
      systype.name = value
      expect(systype.valid?).to eql false
    end
  end
end
