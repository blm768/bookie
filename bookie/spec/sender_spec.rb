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
    @config = Bookie::Config.new('snapshot/test_config.json')
    @config.connect
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
    sys = @sender.system
    Bookie::Database::System.expects(:"create!").never
    sys = @sender.system
  end
  
  it "correctly detects conflicts" do
    csys = Bookie::Database::System.create!(
      {
        :name => @config.hostname,
        :system_type => system_type,
        :start_time => Time.now,
        :cores => @config.cores - 1,
        :memory => @config.memory
      })
    
  end
  
  it "correctly sends jobs" do
    Bookie::Database::Server.expects(:where).returns []
    Bookie::Database::Group.expects(:where).returns []
    Bookie::Database::User.expects(:where).returns []
    server = mock()
    server.expects(:"name=").with("localhost").returns(nil)
    server.expects(:"save!").returns(true)
    Bookie::Database::Server.expects(:new).returns(server)
    group = mock()
    group.expects(:id).returns(nil)
    group.expects(:"name=").with("root").returns(nil)
    group.expects(:"save!").returns(true)
    Bookie::Database::Group.expects(:new).returns(group)
    user = mock()
    user.expects(:"name=").with("root").returns(nil)
    user.expects(:"group=").with(group).returns(nil)
    user.expects(:"save!").returns(true)
    Bookie::Database::User.expects(:new).returns(user)
    db_job = mock()
    db_job.expects(:"server=").with(server).returns(nil)
    db_job.expects(:"user=").with(user).returns(nil)
    db_job.expects(:"save!").returns(true)
    @sender.expects(:each_job).yields(@job)
    @sender.expects(:filter_job).returns(true)
    @sender.expects(:to_database_job).returns(db_job)
    @sender.send_data(Date.today)
  end
  
  it "has a stubbed-out each_job method" do
    expect { @sender.each_job(Date.today)}.to raise_error(NotImplementedError)
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
