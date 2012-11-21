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
    Bookie::Database::drop_tables
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
  
  it "correctly creates systems when they don't exist" do
    Bookie::Database::System.expects(:"create!")
    sys = @sender.system
  end
  
  it "correctly creates systems when only old versions exist" do
    begin
      sys = Bookie::Database::System.create!(
        :name => @config.hostname,
        :start_time => Time.now,
        :end_time => Time.now + 1,
        :system_type => @sender.system_type,
        :cores => @config.cores - 1,
        :memory => @config.memory)
      Bookie::Database::System.expects(:"create!")
      @sender.system
    ensure
      sys.delete
    end
    begin
      Bookie::Database::System.unstub(:"create!")
      sys = @sender.system
      sys.decommission(Time.now + 1)
      Bookie::Database::System.expects(:"create!")
      @sender.system
    ensure
      sys.delete
    end   
  end
  
  it "uses the existing active system" do
    begin
      sys = @sender.system
      Bookie::Database::System.expects(:"create!").never
      sys = @sender.system
    ensure
      sys.delete
    end
  end
  
  it "correctly detects conflicts" do
    begin
      csys = Bookie::Database::System.create!(
        :name => @config.hostname,
        :system_type => @sender.system_type,
        :start_time => Time.now,
        :cores => @config.cores - 1,
        :memory => @config.memory)
      expect { @sender.system }.to raise_error
    ensure
      csys.delete
    end
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
    begin
      @sender.send_data('snapshot/torque_generated')
    rescue => e
      exception = e
    end
    e.should_not eql nil
    e.message.should match /Jobs already exist in the database for the date [\d-]+./
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
