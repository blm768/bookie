require 'spec_helper'

class JobStub
  attr_accessor :user_name
  attr_accessor :group_name
  attr_accessor :command_name
  attr_accessor :start_time
  attr_accessor :end_time
  attr_accessor :wall_time
  attr_accessor :cpu_time
  attr_accessor :memory
  attr_accessor :exit_code
  
  include Bookie::ModelHelpers
end

describe Bookie::Sender do
  before(:all) do
    base_time = Date.new(2012).to_time
    Bookie::Database::Migration.up
    Bookie::Database::System.create!(
      :name => 'localhost',
      :system_type => Bookie::Sender.new(@config).system_type,
      :start_time => base_time,
      :end_time => nil,
      :cores => @config.cores,
      :memory => @config.memory
    )
  end
  
  after(:all) do
    FileUtils.rm('test.sqlite')
  end
  
  before(:each) do
    @sender = Bookie::Sender.new(@config)
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
      @sender.send_data('snapshot/torque_large')
      jobs = Bookie::Database::Job.all_with_relations
      jobs.each do |job|
        job.system.name.should eql @config.hostname
      end
      jobs.length.should eql 100
    ensure
      @config.excluded_users = old_excluded
    end
  end
  
  it "refuses to send jobs when jobs already have been sent from a file" do
    expect {
      @sender.send_data('snapshot/torque_large')
    }.to raise_error("Jobs already exist in the database for 'snapshot/torque_large'.")
  end
  
  it "correctly handles empty files" do
    Bookie::Database::Job.any_instance.expects(:'save!').never
    ActiveRecord::Relation.any_instance.expects(:'delete_all').never
    @sender.send_data('/dev/null')
  end
  
  it "handles missing files" do
    expect { @sender.send_data('snapshot/abc') }.to raise_error("File 'snapshot/abc' does not exist.")
  end
  
  it "chooses the correct systems" do
    @config.expects(:hostname).returns('test').at_least_once
    sender = Bookie::Sender.new(@config)
    sys_type = sender.system_type
    t = Date.new(2012).to_time
    fields = {
      :name => 'test',
      :system_type => sys_type,
      :cores => @config.cores,
      :memory => @config.memory,
    }
    sys_1 = Bookie::Database::System.new(fields)
    sys_1.start_time = t
    sys_1.end_time = t + 1000
    sys_1.save!
    sys_2 = Bookie::Database::System.new(fields)
    sys_2.start_time = t + 1001
    sys_2.end_time = nil
    sys_2.save!
    
    def sender.each_job(filename)
      t = Date.new(2012).to_time
      [0, 1001].each do |offset|
        job = JobStub.new
        job.user_name = 'blm'
        job.group_name = 'blm'
        job.command_name = 'vi'
        job.start_time = t
        job.wall_time = offset
        job.cpu_time = 2
        job.memory = 300
        job.exit_code = 0
        yield job
      end
    end
    
    sender.send_data('snapshot/torque_large')
    
    jobs = Bookie::Database::Job.by_system_name('test').order(:end_time).all
    jobs[0].system.should eql sys_1
    jobs[1].system.should eql sys_2
  end
  
  it "deletes cached summaries that overlap the new jobs" do
    Bookie::Database::Job.delete_all
    sender = Bookie::Sender.new(@config)
    user = Bookie::Database::User.first
    systems = [
      Bookie::Database::System.find_current(sender),
      Bookie::Database::System.create!(
        :name => 'test',
        :system_type => Bookie::Database::SystemType.first,
        :start_time => Time.new,
        :cores => 1,
        :memory => 1000000
      )
    ]
    date_start = Date.new(2012) - 2
    date_end = date_start + 4
    (date_start .. date_end).each do |date|
      systems.each do |system|
        sum = Bookie::Database::JobSummary.create!(
          :date => date,
          :system => system,
          :user => user,
          :command_name => 'vi',
          :num_jobs => 1,
          :cpu_time => 1,
          :memory_time => 100,
          :successful => 1
        )
      end
    end
    sender.send_data('snapshot/torque_large')
    sums = Bookie::Database::JobSummary.all
    sums.length.should eql 9
    sums.each do |sum|
      if sum.system == systems[0]
        sum.date.should_not eql Date.new(2012)
      end
    end
    sums = Bookie::Database::JobSummary.by_date(Date.new(2012)).all
    sums.length.should eql 1
    sums[0].system.should eql systems[1]
  end
end

describe Bookie::ModelHelpers do
  before(:all) do
    @job = JobStub.new
    @job.user_name = "root"
    @job.group_name = "root"
    @job.command_name =  "vi"
    @job.start_time = Time.new
    @job.wall_time = 3
    @job.cpu_time = 2
    @job.memory = 300
  end
  
  #To consider: check user/group somewhere?
  it "correctly converts jobs to models" do
    Bookie::Database::Job.stubs(:new).returns(JobStub.new)
    djob = @job.to_model
    djob.command_name.should eql @job.command_name
    djob.start_time.should eql @job.start_time
    djob.end_time.should eql @job.start_time + @job.wall_time
    djob.wall_time.should eql @job.wall_time
    djob.cpu_time.should eql @job.cpu_time
    djob.memory.should eql @job.memory
    djob.exit_code.should eql @job.exit_code
  end
end
