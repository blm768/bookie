require 'spec_helper'

include Bookie::Database

describe Bookie::Database::Job do
  it "correctly sets end times" do
    Job.find_each do |job|
      job.end_time.should eql job.start_time + job.wall_time
      job.end_time.should eql job.read_attribute(:end_time)
    end
    #Test the update hook.
    job = Job.first
    job.start_time = job.start_time - 1
    job.save!
    job.end_time.should eql job.read_attribute(:end_time)
  end
  
  it "correctly filters by user" do
    user = User.by_name('test').order(:id).first
    jobs = Job.by_user(user).to_a
    jobs.each do |job|
      job.user.should eql user
    end
    jobs.length.should eql 10 
  end
  
  it "correctly filters by user name" do
    jobs = Job.by_user_name('root').to_a
    jobs.length.should eql 10
    jobs[0].user.name.should eql "root"
    jobs = Job.by_user_name('test').order(:end_time).to_a
    jobs.length.should eql 20
    jobs.each do |job|
      job.user.name.should eql 'test'
    end
    jobs[0].user_id.should_not eql jobs[-1].user_id
    jobs = Job.by_user_name('user').to_a
    jobs.length.should eql 0
  end

  it "correctly filters by group name" do
    jobs = Job.by_group_name("root").to_a
    jobs.length.should eql 10
    jobs.each do |job|
      job.user.group.name.should eql "root"
    end
    jobs = Job.by_group_name("admin").order(:start_time).to_a
    jobs.length.should eql 20
    jobs[0].user.name.should_not eql jobs[1].user.name
    jobs = Job.by_group_name("test").to_a
    jobs.length.should eql 0
  end
  
  it "correctly filters by system" do
    sys = System.first
    jobs = Job.by_system(sys)
    jobs.length.should eql 10
    jobs.each do |job|
      job.system.should eql sys
    end
  end
  
  it "correctly filters by system name" do
    jobs = Job.by_system_name('test1')
    jobs.length.should eql 20
    jobs = Job.by_system_name('test2')
    jobs.length.should eql 10
    jobs = Job.by_system_name('test3')
    jobs.length.should eql 10
    jobs = Job.by_system_name('test4')
    jobs.length.should eql 0
  end
  
  it "correctly filters by system type" do
    sys_type = SystemType.find_by_name('Standalone')
    jobs = Job.by_system_type(sys_type)
    jobs.length.should eql 20
    sys_type = SystemType.find_by_name('TORQUE cluster')
    jobs = Job.by_system_type(sys_type)
    jobs.length.should eql 20
  end

  it "correctly filters by command name" do
    jobs = Job.by_command_name('vi')
    jobs.length.should eql 20
    jobs = Job.by_command_name('emacs')
    jobs.length.should eql 20
  end
  
  describe "#by_time_range" do
    it "filters by inclusive time range" do
      jobs = Job.by_time_range(base_time ... base_time + 3600 * 2 + 1)
      jobs.count.should eql 3
      jobs = Job.by_time_range(base_time + 1 ... base_time + 3600 * 2)
      jobs.count.should eql 2
      jobs = Job.by_time_range(base_time ... base_time)
      jobs.length.should eql 0
    end

    it "filters by exclusive time range" do
      jobs = Job.by_time_range(base_time + 1 .. base_time + 3600 * 2)
      jobs.count.should eql 3
      jobs = Job.by_time_range(base_time .. base_time + 3600 * 2 - 1)
      jobs.count.should eql 2
      jobs = Job.by_time_range(base_time .. base_time)
      jobs.count.should eql 1
    end
    
    it "correctly handles empty/inverted ranges" do
      t = base_time
      (-1 .. 0).each do |offset|
        jobs = Job.by_time_range(t ... t + offset)
        jobs.count.should eql 0
      end
    end
  end

  #TODO: implement.
  describe "#within_time_range" do
    it "finds jobs within the range"
  end

  #TODO: implement.
  describe "overlapping_edges" do
    let(:base_start) { base_time }
    let(:base_end) { base_time + 3600 }

    context "with exclusive ranges" do
      it "finds jobs that overlap the edges" do
        #Overlapping beginning
        jobs = Job.overlapping_edges(base_start + 1 ... base_end)
        expect(jobs.length).to eql 1
        expect(jobs.first.start_time).to eql base_time
        
        #Overlapping end
        jobs = Job.overlapping_edges(base_start ... base_end - 1)
        expect(jobs.length).to eql 1
        expect(jobs.first.start_time).to eql base_time

        #One job overlapping both
        jobs = Job.overlapping_edges(base_start + 1 ... base_end - 1)
        expect(jobs.length).to eql 1
        expect(jobs.first.start_time).to eql base_time

        #Two jobs overlapping the endpoints
        jobs = Job.overlapping_edges(base_end - 1 ... base_end + 1) 
        expect(jobs.length).to eql 2
        
        #Not overlapping any endpoints
        jobs = Job.overlapping_edges(base_start ... base_end)
        expect(jobs.length).to eql 0
        jobs = Job.overlapping_edges(base_start + 1 ... base_start + 1)
        expect(jobs.length).to eql 0
      end
    end

    context "with inclusive ranges" do
      it "finds jobs that overlap the edges" do
        #This is more pared-down because inclusive and exclusive ranges mostly
        #share the same codepath.
        jobs = Job.overlapping_edges(base_start .. base_end)
        expect(jobs.length).to eql 1

        jobs = Job.overlapping_edges(base_start .. base_start)
        expect(jobs.length).to eql 1
      end
    end
  end
   
  describe "#all_with_relations" do
    it "loads all relations" do
      jobs = Job.limit(5).all_with_relations
      relation_ids = {}
      User.expects(:new).never
      Group.expects(:new).never
      System.expects(:new).never
      SystemType.expects(:new).never
      jobs.each do |job|
        test_job_relation_identity(job, relation_ids)
      end
    end
  end
  
  describe "#summary" do
    let(:length) { Job.count }
    let(:summary) { create_summaries(Job, base_time) }
    
    it "produces correct summary totals" do
      summary[:all][:num_jobs].should eql length
      summary[:all][:successful].should eql 20
      summary[:all][:cpu_time].should eql length * 100
      summary[:all][:memory_time].should eql length * 200 * 3600
      expect(summary[:all_constrained]).to eql(summary[:all])
      summary[:all_filtered][:num_jobs].should eql length / 2
      summary[:all_filtered][:successful].should eql 20
      summary[:all_filtered][:cpu_time].should eql length * 100 / 2
      summary[:all_filtered][:memory_time].should eql length * 100 * 3600
      num_clipped_jobs = summary[:clipped][:num_jobs]
      num_clipped_jobs.should eql 25
      summary[:clipped][:cpu_time].should eql num_clipped_jobs * 100 - 50
      summary[:clipped][:memory_time].should eql num_clipped_jobs * 200 * 3600 - 100 * 3600
      summary[:clipped][:successful].should eql num_clipped_jobs / 2 + 1
    end
    
    it "correctly handles summaries of empty sets" do
      summary[:empty].should eql({
          :num_jobs => 0,
          :cpu_time => 0,
          :memory_time => 0,
          :successful => 0,
        })
    end
    
    it "correctly handles inverted ranges" do
      Job.summary(Time.now() ... Time.now() - 1).should eql summary[:empty]
      Job.summary(Time.now() .. Time.now() - 1).should eql summary[:empty]
    end

    it "distinguishes between inclusive and exclusive ranges" do
      sum = Job.summary(base_time ... base_time + 3600)
      sum[:num_jobs].should eql 1
      sum = Job.summary(base_time .. base_time + 3600)
      sum[:num_jobs].should eql 2
    end
  end
  
  it "validates fields" do
    fields = {
      :user => User.first,
      :system => System.first,
      :command_name => '',
      :cpu_time => 100,
      :start_time => base_time,
      :wall_time => 1000,
      :memory => 10000,
      :exit_code => 0
    }
    
    job = Job.new(fields)
    job.valid?.should eql true
    
    fields.each_key do |field|
      job = Job.new(fields)
      job.method("#{field}=".intern).call(nil)
      job.valid?.should eql false
    end
    
    [:cpu_time, :wall_time, :memory].each do |field|
      job = Job.new(fields)
      m = job.method("#{field}=".intern)
      m.call(-1)
      job.valid?.should eql false
      m.call(0)
      job.valid?.should eql true
    end
  end
end

