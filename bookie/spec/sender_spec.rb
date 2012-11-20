require 'spec_helper'

class JobStub
  attr_accessor :user_name
  attr_accessor :group_name
  attr_accessor :start_time
  attr_accessor :end_time
  attr_accessor :wall_time
  attr_accessor :cpu_time
  attr_accessor :memory
  attr_accessor :exit_code
end

describe Bookie::Sender::Sender do
  before(:each) do
    @sender = Bookie::Sender::Sender.new(@config)
    @job = JobStub.new
    @job.user_name = "root"
    @job.group_name = "root"
    @job.start_time = Time.new
    @job.wall_time = 3
    @job.cpu_time = 2
    @job.memory = 300
    @job.exit_code = 0
  end
  
  it "correctly filters jobs" do
    job = JobStub.new
    job.user_name = "root"
    @sender.filtered?(job).should eql true
    job.user_name = "test"
    @sender.filtered?(job).should eql false
  end
  
  it "correctly creates systems when they don't exist" do
    Bookie::Database::System.expects(:"create!")
    sys = @sender.system
  end
  
  it "uses the existing active system" do
    #To do: possible failure cases:
    #* System exists w/ different specs
    #* Decommissioned system exists w/ same specs
    sys = @sender.system
    Bookie::Database::System.expects(:"create!").never
    sys = @sender.system
    sys.delete
  end
  
  it "correctly detects conflicts" do
    csys = Bookie::Database::System.create!(
      :name => @config.hostname,
      :system_type => @sender.system_type,
      :start_time => Time.now,
      :cores => @config.cores - 1,
      :memory => @config.memory)
    expect { @sender.system }.to raise_error
  end
  
  it "correctly sends jobs" do
    @sender.send_data('snapshot/pacct')
    count = 0
    Bookie::Database::Job.each_with_relations do |job|
      job.system.name.should eql @config.hostname
      count += 1
    end
    count.should eql 100
  end
  
  it "refuses to send jobs when jobs already have been sent from a file"
  
  it "handles missing files"
end

describe Bookie::Sender::ModelHelpers do
  before(:all) do
    @job = JobStub.new
    @job.user_name = "root"
    @job.group_name = "root"
    @job.start_time = Time.new
    @job.wall_time = 3
    @job.cpu_time = 2
    @job.memory = 300
    @job.extend(Bookie::Sender::ModelHelpers)
  end
  
  it "correctly converts jobs to database objects" do
    Bookie::Database::Job.stubs(:new).returns(JobStub.new)
    djob = @job.to_model
    djob.start_time.should eql @job.start_time
    djob.end_time.should eql @job.start_time + @job.wall_time
    djob.wall_time.should eql @job.wall_time
    djob.cpu_time.should eql @job.cpu_time
    djob.memory.should eql @job.memory
    djob.exit_code.should eql @job.exit_code
  end
end
