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
      job.user_name.should eql "blm768"
      job.group_name.should eql "test"
      job.start_time.should eql Time.at(1349679637)
      job.exit_code.should eql 0
      n += 1
    end
    n.should eql 1
  end
end