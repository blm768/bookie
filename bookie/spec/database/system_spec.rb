require 'spec_helper'

include Bookie::Database

describe Bookie::Database::System do
  describe "#active" do
    it { expect(System.active.length).to eql 3 }
  end

  describe "#decommission!" do
    it "correctly decommissions" do
      sys = System.find_by(name: 'test1')
      cap = sys.current_capacity
      sys.decommission!(cap.start_time + 3)
      cap = sys.system_capacities.order('start_time DESC').first
      expect(cap.end_time).to eql cap.start_time + 3
    end
  end

  #TODO: re-check all validation tests?
  it "validates fields" do
    fields = {
      name: 'test',
      system_type: SystemType.first,
    }

    expect(System.new(fields).valid?).to eql true

    fields.each_key do |field|
      system = System.new(fields)
      system.method("#{field}=".intern).call(nil)
      expect(system.valid?).to eql false
    end

    system = System.new(fields)
    system.name = ''
    expect(system.valid?).to eql false
  end
end
