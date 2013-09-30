require 'spec_helper'

describe Bookie::Database::Job do
  before(:each) do
    @jobs = Bookie::Database::Job
  end
  
  it "correctly sets end times" do
    @jobs.find_each do |job|
      job.end_time.should eql job.start_time + job.wall_time
      job.end_time.should eql job.read_attribute(:end_time)
    end
    #Test the update hook.
    job = Bookie::Database::Job.first
    job.start_time = job.start_time - 1
    job.save!
    job.end_time.should eql job.read_attribute(:end_time)
  end
  
  it "correctly filters by user" do
    user = Bookie::Database::User.by_name('test').order(:id).first
    jobs = @jobs.by_user(user).to_a
    jobs.each do |job|
      job.user.should eql user
    end
    jobs.length.should eql 10 
  end
  
  it "correctly filters by user name" do
    jobs = @jobs.by_user_name('root').to_a
    jobs.length.should eql 10
    jobs[0].user.name.should eql "root"
    jobs = @jobs.by_user_name('test').order(:end_time).to_a
    jobs.length.should eql 20
    jobs.each do |job|
      job.user.name.should eql 'test'
    end
    jobs[0].user_id.should_not eql jobs[-1].user_id
    jobs = @jobs.by_user_name('user').to_a
    jobs.length.should eql 0
  end

  it "correctly filters by group name" do
    jobs = @jobs.by_group_name("root").to_a
    jobs.length.should eql 10
    jobs.each do |job|
      job.user.group.name.should eql "root"
    end
    jobs = @jobs.by_group_name("admin").order(:start_time).to_a
    jobs.length.should eql 20
    jobs[0].user.name.should_not eql jobs[1].user.name
    jobs = @jobs.by_group_name("test").to_a
    jobs.length.should eql 0
  end
  
  it "correctly filters by system" do
    sys = Bookie::Database::System.first
    jobs = @jobs.by_system(sys)
    jobs.length.should eql 10
    jobs.each do |job|
      job.system.should eql sys
    end
  end
  
  it "correctly filters by system name" do
    jobs = @jobs.by_system_name('test1')
    jobs.length.should eql 20
    jobs = @jobs.by_system_name('test2')
    jobs.length.should eql 10
    jobs = @jobs.by_system_name('test3')
    jobs.length.should eql 10
    jobs = @jobs.by_system_name('test4')
    jobs.length.should eql 0
  end
  
  it "correctly filters by system type" do
    sys_type = Bookie::Database::SystemType.find_by_name('Standalone')
    jobs = @jobs.by_system_type(sys_type)
    jobs.length.should eql 20
    sys_type = Bookie::Database::SystemType.find_by_name('TORQUE cluster')
    jobs = @jobs.by_system_type(sys_type)
    jobs.length.should eql 20
  end

  it "correctly filters by command name" do
    jobs = @jobs.by_command_name('vi')
    jobs.length.should eql 20
    jobs = @jobs.by_command_name('emacs')
    jobs.length.should eql 20
  end
  
  it "correctly filters by start time" do
    jobs = @jobs.by_start_time_range(base_time ... base_time + 3600 * 2 + 1)
    jobs.length.should eql 3
    jobs = @jobs.by_start_time_range(base_time + 1 ... base_time + 3600 * 2)
    jobs.length.should eql 1
    jobs = @jobs.by_start_time_range(Time.at(0) ... Time.at(3))
    jobs.length.should eql 0
  end
  
  it "correctly filters by end time" do
    jobs = @jobs.by_end_time_range(base_time ... base_time + 3600 * 2 + 1)
    jobs.length.should eql 2
    jobs = @jobs.by_end_time_range(base_time + 1 ... base_time + 3600 * 2)
    jobs.length.should eql 1
    jobs = @jobs.by_end_time_range(Time.at(0) ... Time.at(3))
    jobs.length.should eql 0
  end
  
  describe "#by_time_range" do
    it "correctly filters by time range" do
      jobs = @jobs.by_time_range(base_time ... base_time + 3600 * 2 + 1)
      jobs.count.should eql 3
      jobs = @jobs.by_time_range(base_time + 1 ... base_time + 3600 * 2)
      jobs.count.should eql 2
      jobs = @jobs.by_time_range(base_time ... base_time)
      jobs.length.should eql 0
      jobs = @jobs.by_time_range(base_time .. base_time + 3600 * 2)
      jobs.count.should eql 3
      jobs = @jobs.by_time_range(base_time .. base_time)
      jobs.count.should eql 1
    end
    
    it "correctly handles empty/inverted ranges" do
      t = base_time
      (-1 .. 0).each do |offset|
        jobs = @jobs.by_time_range(t ... t + offset)
        jobs.count.should eql 0
      end
    end
  end

  #TODO: implement.
  describe "#within_time_range"
   
  describe "#all_with_relations" do
    it "loads all relations" do
      jobs = Bookie::Database::Job.limit(5).all_with_relations
      relation_ids = {}
      Bookie::Database::User.expects(:new).never
      Bookie::Database::Group.expects(:new).never
      Bookie::Database::System.expects(:new).never
      Bookie::Database::SystemType.expects(:new).never
      jobs.each do |job|
        test_job_relation_identity(job, relation_ids)
      end
    end
  end
  
  describe "#summary" do
    before(:all) do
      @jobs = Bookie::Database::Job
      @length = @jobs.count
      @summary = create_summaries(@jobs, base_time)
    end
    
    it "produces correct summary totals" do
      @summary[:all][:num_jobs].should eql @length
      @summary[:all][:successful].should eql 20
      @summary[:all][:cpu_time].should eql @length * 100
      @summary[:all][:memory_time].should eql @length * 200 * 3600
      expect(@summary[:all_constrained]).to eql(@summary[:all])
      @summary[:all_filtered][:num_jobs].should eql @length / 2
      @summary[:all_filtered][:cpu_time].should eql @length * 100 / 2
      @summary[:all_filtered][:successful].should eql 20
      @summary[:all_filtered]
      clipped_jobs = @summary[:clipped][:num_jobs]
      clipped_jobs.should eql 25
      @summary[:clipped][:cpu_time].should eql clipped_jobs * 100 - 50
      @summary[:clipped][:memory_time].should eql clipped_jobs * 200 * 3600 - 100 * 3600
      @summary[:clipped][:successful].should eql clipped_jobs / 2 + 1
    end
    
    it "correctly handles summaries of empty sets" do
      @summary[:empty].should eql({
          :num_jobs => 0,
          :cpu_time => 0,
          :memory_time => 0,
          :successful => 0,
        })
    end
    
    it "correctly handles summaries with zero wall time" do
      job = @jobs.order(:start_time).first
      wall_time = job.wall_time
      begin
        job.wall_time = 0
        job.save!
        @jobs.order(:start_time).limit(1).summary[:cpu_time].should eql 0
      ensure
        job.wall_time = wall_time
        job.save!
      end
    end
    
    it "correctly handles inverted ranges" do
      @jobs.summary(Time.now() ... Time.now() - 1).should eql @summary[:empty]
      @jobs.summary(Time.now() .. Time.now() - 1).should eql @summary[:empty]
    end

    it "distinguishes between inclusive and exclusive ranges" do
      sum = @jobs.summary(base_time ... base_time + 3600)
      sum[:num_jobs].should eql 1
      sum = @jobs.summary(base_time .. base_time + 3600)
      sum[:num_jobs].should eql 2
    end
  end
  
  it "validates fields" do
    fields = {
      :user => Bookie::Database::User.first,
      :system => Bookie::Database::System.first,
      :command_name => '',
      :cpu_time => 100,
      :start_time => base_time,
      :wall_time => 1000,
      :memory => 10000,
      :exit_code => 0
    }
    
    job = Bookie::Database::Job.new(fields)
    job.valid?.should eql true
    
    fields.each_key do |field|
      job = Bookie::Database::Job.new(fields)
      job.method("#{field}=".intern).call(nil)
      job.valid?.should eql false
    end
    
    [:cpu_time, :wall_time, :memory].each do |field|
      job = Bookie::Database::Job.new(fields)
      m = job.method("#{field}=".intern)
      m.call(-1)
      job.valid?.should eql false
      m.call(0)
      job.valid?.should eql true
    end
  end
end

