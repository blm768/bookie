require 'spec_helper'

include Bookie::Database

describe Bookie::Database::SystemType do
  describe "#memory_stat_type" do
    let(:systype) { SystemType.new }

    it "correctly maps memory stat type codes to symbols" do
      SystemType::MEMORY_STAT_TYPE.each_pair do |symbol, code|
        systype.set_attribute(:memory_stat_type, code)
        expect(systype.memory_stat_type).to eql symbol
      end
    end

    it "rejects unrecognized memory stat type codes" do
      systype.send(:write_attribute, :memory_stat_type, 10000)
      expect { systype.memory_stat_type }.to raise_error("Unrecognized memory stat type code 10000")
    end

    it "handles nil values" do
      systype.send(:write_attribute, :memory_stat_type, nil)
      expect(systype.memory_stat_type).to eql nil
    end
  end

  describe "#memory_stat_type=" do
    let(:systype) { SystemType.new }

    it "correctly maps memory stat type symbols to codes" do
      SystemType::MEMORY_STAT_TYPE.each_pair do |symbol, code|
        systype.memory_stat_type = symbol
        expect(systype.read_attribute(:memory_stat_type)).to eql code
      end
    end

    it "rejects unrecognized memory stat type symbols" do
      systype = SystemType.new
      expect { systype.memory_stat_type = :invalid_type }.to raise_error("Unrecognized memory stat type 'invalid_type'")
    end

    it "handles nil values" do
      systype.memory_stat_type = nil
      expect(systype.read_attribute(:memory_stat_type)).to eql nil
    end
  end

  describe "#find_or_create" do
    it "creates the system type when needed" do
      SystemType.expects(:'create!')
      SystemType.find_or_create!('test', :avg)
    end

    #TODO: make error messages better?
    it "raises an error if the existing type has the wrong memory stat type" do
      systype = SystemType.create!(:name => 'test', :memory_stat_type => :max)
      #TODO: create a custom error class so we don't hard-code the error message here.
      expect {
        SystemType.find_or_create!('test', :avg)
      }.to raise_error("The recorded memory stat type for system type 'test' does not match the required type of 1")
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
