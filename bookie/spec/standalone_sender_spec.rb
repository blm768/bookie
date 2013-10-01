require 'spec_helper'

require 'pacct'

#Stubbed out for now so the 'describe' line works
module Bookie
  module Senders
    module Standalone
      
    end
  end
end

describe Bookie::Senders::Standalone do
  let(:config) { Bookie::Config.new('snapshot/pacct_test_config.json') }
  let(:sender) { Bookie::Sender.new(config) }
  
  it "correctly yields jobs" do
    sender.each_job('snapshot/pacct') do |job|
      job.class.should eql Pacct::Entry
      job.user_name.should eql 'root'
    end
  end
  
  it "has the correct system type name" do
    sender.system_type_name.should eql 'Standalone'
  end
  
  it "has the correct memory stat type" do
    sender.memory_stat_type.should eql :avg
  end
end

describe Pacct::Entry do
  it "has a to_record method" do
    Pacct::Entry.new.respond_to?(:to_record).should eql true
  end
end

