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
  before(:all) do
    Bookie::Database::create_tables
  end
  
  after(:all) do
    FileUtils.rm('spec/test.sqlite')
  end
  
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
  
  it "correctly sends jobs" do
    old_excluded = @config.excluded_users
    @config.excluded_users = Set.new
    begin
      @sender.send_data('snapshot/torque_generated')
      count = 0
      Bookie::Database::Job.each_with_relations do |job|
        job.system.name.should eql @config.hostname
        count += 1
      end
      count.should eql 100
    ensure
      @config.excluded_users = old_excluded
    end
  end
  
  it "refuses to send jobs when jobs already have been sent from a file" do
    exception = nil
    expect {
      @sender.send_data('snapshot/torque_generated')
    }.to raise_error(/^Jobs already exist in the database for the date [\d]{4}-[\d]{2}-[\d]{2}.$/)
  end
  
  it "handles missing files" do
    expect { @sender.send_data('snapshot/abc') }.to raise_error
  end
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
