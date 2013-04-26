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
    Bookie::Database::Migration.up
    t = Time.utc(2012)
    fields = {
      :name => 'localhost',
      :system_type => Bookie::Sender.new(@config).system_type,
      :cores => @config.cores,
      :memory => @config.memory,
    }
    @sys_1 = Bookie::Database::System.new(fields)
    @sys_1.start_time = t
    @sys_1.end_time = t + 1000
    @sys_1.save!
    @sys_2 = Bookie::Database::System.new(fields)
    @sys_2.start_time = t + 1001
    @sys_2.end_time = nil
    @sys_2.save!
    fields[:name] = 'dummy'
    @sys_dummy = Bookie::Database::System.new(fields)
    @sys_dummy.start_time = t
    @sys_dummy.save!
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
    Bookie::Database::Job.delete_all
    sender = Bookie::Sender.new(@config)
        
    def sender.each_job(filename)
      t = Time.utc(2012)
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
    
    #The filename is just a dummy argument.
    sender.send_data('snapshot/pacct')
    
    jobs = Bookie::Database::Job.by_system_name(@config.hostname).order(:end_time).all
    jobs[0].system.should eql @sys_1
    jobs[1].system.should eql @sys_2
  end
  
  it "deletes cached summaries that overlap the new jobs" do
    Bookie::Database::Job.delete_all
    @sender.send_data('snapshot/torque_large')
    time_min = Bookie::Database::Job.order(:start_time).first.start_time
    time_max = Bookie::Database::Job.order('end_time DESC').first.end_time
    Bookie::Database::Job.delete_all
    @sender.expects(:clear_summaries).with(time_min.to_date, time_max.to_date)
    @sender.send_data('snapshot/torque_large')
  end
  
  describe "#clear_summaries" do
    it "deletes cached summaries" do
      Bookie::Database::Job.delete_all
      sender = Bookie::Sender.new(@config)
      sender.send_data('snapshot/torque_large')
      
      user = Bookie::Database::User.first
      date_start = Date.new(2012) - 2
      date_end = date_start + 4
      (date_start .. date_end).each do |date|
        [@sys_1, @sys_2, @sys_dummy].each do |system|
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
      
      sender.send(:clear_summaries, date_start + 1, date_end - 1)
      
      sums = Bookie::Database::JobSummary.all
      sums.length.should eql 9
      sums.each do |sum|
        unless sum.system == @sys_dummy
          (date_start + 1 .. date_end - 1).cover?(sum.date).should eql false
        end
      end
      sums = Bookie::Database::JobSummary.by_date(Date.new(2012))
      sums.count.should eql 1
      sums.first.system.should eql @sys_dummy
    end
  end
  
  describe "#undo_send" do
    it "removes the correct entries" do
      Bookie::Database::Job.delete_all
      @sender.send_data('snapshot/torque_large')
      @sender.send_data('snapshot/torque')
      @sender.undo_send('snapshot/torque_large')
      
      Bookie::Database::Job.count.should eql 1
      job = Bookie::Database::Job.first
      Bookie::Database::Job.delete_all
      @sender.send_data('snapshot/torque')
      job2 = Bookie::Database::Job.first
      job2.id = job.id
      job2.should eql job
    end
    
    it "deletes cached summaries in the affected range" do
      Bookie::Database::Job.delete_all
      @sender.send_data('snapshot/torque_large')
      time_min = Bookie::Database::Job.order(:start_time).first.start_time
      time_max = Bookie::Database::Job.order('end_time DESC').first.end_time
      @sender.expects(:clear_summaries).with(time_min.to_date, time_max.to_date)
      @sender.undo_send('snapshot/torque_large')
    end
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
