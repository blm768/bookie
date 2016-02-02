require 'spec_helper'

require 'bookie/senders/standalone.rb'

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
      expect(job.class).to eql Pacct::Entry
      expect(job.user_name).to eql 'root'
    end
  end

  it "has the correct system type name" do
    expect(sender.system_type_name).to eql 'Standalone'
  end

  it "has the correct memory stat type" do
    expect(sender.memory_stat_type).to eql :avg
  end
end

describe Pacct::Entry do
  it { expect(Pacct::Entry.new).to respond_to(:to_record) }
end

