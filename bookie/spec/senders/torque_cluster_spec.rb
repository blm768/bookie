require 'spec_helper'

require 'bookie/senders/torque_cluster.rb'

#Stubbed out for now so the 'describe' line works
module Bookie
  module Senders
    module TorqueCluster
      
    end
  end
end

module Torque
  class Job
  
  end
  
  class JobLog
  
  end
end

describe Bookie::Senders::TorqueCluster do
  let(:config) { Bookie::Config.new('snapshot/test_config.json') }
  let(:sender) { Bookie::Sender.new(config) }
  
  it "correctly yields jobs" do
    sender.each_job('snapshot/torque') do |job|
      job.class.should eql Torque::Job
      job.user_name.should eql 'blm768'
    end
  end
  
  it "has the correct system type name" do
    sender.system_type_name.should eql 'TORQUE cluster'
  end
  
  it "has the correct memory stat type" do
    sender.memory_stat_type.should eql :max
  end
end

describe Torque::Job do
  it { expect(Torque::Job.new).to respond_to(:to_record) }
end

describe Torque::JobLog do
  before(:each) do
    @log = Torque::JobLog.new('snapshot/torque')
  end
  
  it "throws an error if the file does not exist" do
    expect { Torque::JobLog.new('snapshot/abc') }.to raise_error
  end
  
  it "correctly reads data" do
    n = 0
    @log.each_job do |job|
      job.user_name.should eql "blm768"
      job.group_name.should eql "test"
      job.start_time.should eql Time.at(1349679573)
      job.wall_time.should eql 67
      job.cpu_time.should eql 63
      job.physical_memory.should eql 139776
      job.virtual_memory.should eql 173444
      job.memory.should eql job.physical_memory + job.virtual_memory
      job.exit_code.should eql 0
      n += 1
    end
    #One of the entries in the file is not a job end entry and should be skipped.
    n.should eql 1
  end
  
  it "can read data more than once" do
    2.times do
      n = 0
      @log.each_job do |job|
        n += 1
      end
      n.should eql 1
    end
  end
  
  it "correctly parses durations" do
    @log.send(:parse_duration, "01:02:03").should eql 3723
  end
  
  it "raises errors when lines are invalid" do
    log = Torque::JobLog.new('snapshot/torque_invalid_lines')
    expect { log.each_job }.to raise_error(
      Torque::JobLog::InvalidLineError,
      "Line 1 of file 'snapshot/torque_invalid_lines' is invalid."
    )
    (2 ... 3).each do |i|
      log = Torque::JobLog.new("snapshot/torque_invalid_lines_#{i}")
      expect { log.each_job {} }.to raise_error(
        Torque::JobLog::InvalidLineError,
        "Line 3 of file 'snapshot/torque_invalid_lines_#{i}' is invalid."
      )
    end
  end
  
  it "correctly calculates the filename for a date" do
    Torque::JobLog.filename_for_date(Date.new(2012, 1, 3)).should eql Torque::torque_root + '/server_priv/accounting/20120103'
  end
end
