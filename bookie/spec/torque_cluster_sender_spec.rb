require 'spec_helper'

require 'torque_stats'

#Stubbed out for now so the 'describe' line works
module Bookie
  module Senders
    module TorqueCluster
      
    end
  end
end

describe Bookie::Senders::TorqueCluster do
  before(:all) do
    config = Bookie::Config.new('snapshot/test_config.json')
    @sender = Bookie::Sender::Sender.new(config)
  end
  
  it "correctly yields jobs" do
    @sender.each_job('snapshot/torque') do |job|
      job.class.should eql TorqueStats::Job
      job.user_name.should eql 'blm768'
    end
  end
  
  it "has the correct system type name" do
    @sender.system_type_name.should eql 'TORQUE cluster'
  end
  
  it "has the correct memory stat type" do
    @sender.memory_stat_type.should eql :max
  end
end

describe TorqueStats::Job do
  it "has a to_model method" do
    TorqueStats::Job.new.respond_to?(:to_model).should eql true
  end
end
