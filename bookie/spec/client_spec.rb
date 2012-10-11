require 'spec_helper'

class JobStub
  attr_accessor :user_name
end

describe Bookie::Client do
  before(:each) do
    @config = Bookie::Config.new('snapshot/config.json')
    @client = Bookie::Client.new(@config)
  end
  
  it "correctly filters jobs" do
    job = JobStub.new
    job.user_name = "root"
    @client.filter_job(job).should eql nil
    job.user_name = "test"
    @client.filter_job(job).should eql job
  end
  
  it "has a stubbed-out send_data method" do
    expect { @client.send_data(nil) }.to raise_error(NotImplementedError)
  end
end
