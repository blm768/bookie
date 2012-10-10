require 'spec_helper'

require 'date'

describe TorqueStats::JobRecord do
  before(:each) do
    TorqueStats::torque_root = 'snapshot'
    @record = TorqueStats::JobRecord.new(Date.new(2012, 10, 8))
  end
  
  it "Reads the correct file" do
    @record.filename.should eql File.join(TorqueStats::torque_root, 'server_priv/accounting/20121008')
  end
  
  it "Correctly reads data" do
    n = 0
    @record.each_job do |job|
      puts job.user_name
      n += 1
      break unless n < 5
    end
  end
end