require 'spec_helper'

module Helpers
  #Used for the "chooses the correct systems" examples
  def redefine_each_job(sender)
    def sender.each_job(filename)
      [0, 1001].each do |offset|
        job = JobStub.new
        job.user_name = 'blm'
        job.group_name = 'blm'
        job.command_name = 'vi'
        job.start_time = Helpers::BASE_TIME + offset
        job.wall_time = 1000
        job.cpu_time = 2
        job.memory = 300
        job.exit_code = 0
        yield job
      end
    end
  end
end

class JobStub
  attr_accessor :user_name
  attr_accessor :group_name
  attr_accessor :command_name
  attr_accessor :start_time
  attr_accessor :wall_time
  attr_accessor :cpu_time
  attr_accessor :memory
  attr_accessor :exit_code
  
  include Bookie::ModelHelpers

  def self.from_job(job)
    stub = self.new
    stub.user_name = job.user.name
    stub.group_name = job.user.group.name
    stub.command_name = job.command_name
    stub.start_time = job.start_time
    stub.wall_time = job.wall_time
    stub.cpu_time = job.cpu_time
    stub.memory = job.memory
    stub.exit_code = job.exit_code
    stub
  end
end

describe Bookie::Sender do
  before(:all) do
    begin_transaction
    fields = {
      :name => test_config.hostname,
      :system_type => Bookie::Sender.new(test_config).system_type,
      :cores => test_config.cores,
      :memory => test_config.memory,
    }
    @sys_1 = Bookie::Database::System.new(fields)
    @sys_1.start_time = base_time
    @sys_1.end_time = base_time + 1000
    @sys_1.save!
    @sys_2 = Bookie::Database::System.new(fields)
    @sys_2.start_time = base_time + 1001
    @sys_2.end_time = nil
    @sys_2.save!

    fields[:name] = 'dummy'
    @sys_dummy = Bookie::Database::System.new(fields)
    @sys_dummy.start_time = base_time
    @sys_dummy.save!
  end

  after(:all) do
    rollback_transaction
  end
  
  before(:each) do
    @sender = Bookie::Sender.new(test_config)
    Bookie::Database::Job.delete_all
  end
  
  it "correctly filters jobs" do
    job = JobStub.new
    job.user_name = "root"
    @sender.filtered?(job).should eql true
    job.user_name = "test"
    @sender.filtered?(job).should eql false
  end
  
  it "correctly sends jobs" do
    config = test_config.clone
    config.excluded_users = Set.new
    @sender.send_data('snapshot/torque_large')
    jobs = Bookie::Database::Job.all_with_relations
    jobs.each do |job|
      job.system.name.should eql config.hostname
    end
    jobs.length.should eql 100
  end
  
  it "refuses to send jobs when jobs already have been sent from a file" do
    @sender.send_data('snapshot/torque_large')
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
    sender = Bookie::Sender.new(test_config)

    redefine_each_job(sender)
   
    #The filename is just a dummy argument.
    sender.send_data('snapshot/pacct')
    
    jobs = Bookie::Database::Job.by_system_name(test_config.hostname).order(:end_time).to_a
    jobs[0].system.should eql @sys_1
    jobs[1].system.should eql @sys_2
  end

  it "correctly finds duplicates" do
    @sender.send_data('snapshot/torque')
    job = Bookie::Database::Job.first
    stub = JobStub.from_job(job)
    #The job's system should be @sys_2.
    #Just to make sure this test doesn't break later, I'll check it.
    #expect(job.system).to eql @sys_2
    #@sender.duplicate(stub, @sys_1).should eql nil
    @sender.duplicate(stub, job.system).should eql job
    [:user_name, :group_name, :command_name, :start_time, :wall_time, :cpu_time, :memory, :exit_code].each do |field|
      old_val = stub.send(field)
      if old_val.is_a?(String)
        stub.send("#{field}=", 'string')
      else
        stub.send("#{field}=", old_val + 1)
      end
      @sender.duplicate(stub, @sys_2).should eql nil
      stub.send("#{field}=", old_val)
    end
  end
  
  it "deletes cached summaries that overlap the new jobs" do
    @sender.send_data('snapshot/torque_large')
    time_min = Bookie::Database::Job.order(:start_time).first.start_time
    time_max = Bookie::Database::Job.order('end_time DESC').first.end_time
    Bookie::Database::Job.delete_all
    @sender.expects(:clear_summaries).with(time_min.to_date, time_max.to_date)
    @sender.send_data('snapshot/torque_large')
  end
  
  describe "#clear_summaries" do
    it "deletes cached summaries" do
      sender = Bookie::Sender.new(test_config)
      sender.send_data('snapshot/torque_large')
      
      user = Bookie::Database::User.first
      date_start = Date.new(2012) - 2
      date_end = date_start + 4
      (date_start .. date_end).each do |date|
        [@sys_1, @sys_2, @sys_dummy].each do |system|
          Bookie::Database::JobSummary.create!(
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
      
      sums = Bookie::Database::JobSummary.all.to_a
      sums.length.should eql 9
      sums.each do |sum|
        #Since there are no jobs for @sys_dummy, its summaries should be left intact.
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

    it "switches systems if needed" do
      sender = Bookie::Sender.new(test_config)

      redefine_each_job(sender)
     
      #The filename is just a dummy argument.
      sender.send_data('snapshot/pacct')

      def sender.duplicate(job, system)
        #The returned object needs a #delete method.
        job.expects(:delete)
        job
      end

      Bookie::Database::System.expects(:find_current).returns(Bookie::Database::System.first)

      sender.undo_send('snapshot/pacct')
    end

    it "deletes cached summaries in the affected range" do
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

  it "correctly calculates end time" do
    @job.end_time.should eql @job.start_time + @job.wall_time
  end
end

