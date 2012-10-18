require 'spec_helper'

require 'socket'

class JobStub
  attr_accessor :date
  attr_accessor :user_name
  attr_accessor :group_name
  attr_accessor :start_time
  attr_accessor :wall_time
  attr_accessor :cpu_time
  attr_accessor :memory
end

describe Bookie::Client do
  before(:each) do
    @config = Bookie::Config.new('snapshot/test_config.json')
    @client = Bookie::Client.new(@config)
    @job = JobStub.new
    @job.user_name = "root"
    @job.group_name = "root"
    @job.start_time = Time.new
    @job.wall_time = 3
    @job.cpu_time = 2
    @job.memory = 300
  end
  
  it "correctly filters jobs" do
    job = JobStub.new
    job.user_name = "root"
    @client.filter_job(job).should eql nil
    job.user_name = "test"
    @client.filter_job(job).should eql job
  end
  
  it "correctly converts jobs to database objects" do
    Bookie::Database::Job.stubs(:new).returns(JobStub.new)
    djob = @client.to_database_job(@job)
    djob.date.should eql (djob.start_time + djob.wall_time).to_date
    djob.start_time.should eql @job.start_time
    djob.wall_time.should eql @job.wall_time
    djob.cpu_time.should eql @job.cpu_time
    djob.memory.should eql @job.memory
  end
  
  it "correctly sends jobs" do
    Socket.expects(:gethostbyname).returns(["localhost"])
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
    @client.expects(:each_job).yields(@job)
    @client.expects(:filter_job).returns(true)
    @client.expects(:to_database_job).returns(db_job)
    @client.send_data(Date.today)
  end
  
  it "has a stubbed-out each_job method" do
    expect { @client.each_job(Date.today)}.to raise_error(NotImplementedError)
  end
  
  it "attempts to connect to the database" do
    ActiveRecord::Base.stubs(:logger=).returns(nil).at_least_once
    ActiveRecord::Base.stubs(:establish_connection).returns(nil).at_least_once
    @client.connect
  end
end
