require 'spec_helper'

describe Bookie::Database do
  before(:all) do
    Helpers::generate_database
  end
  
  after(:all) do
    Bookie::Database::drop_tables
  end
  
  describe Bookie::Database::Job do
    before(:each) do
      @jobs = Bookie::Database::Job
      @base_time = @jobs.first.start_time
    end
    
    it "correctly filters by user" do
      jobs = @jobs.by_user_name('root').all
      jobs.length.should eql 25
      jobs[0].memory.should eql 1024
      jobs[0].user.name.should eql "root"
      jobs = @jobs.by_user_name('test').order(:end_time).all
      jobs.length.should eql 50
      jobs.each do |job|
        job.user.name.should eql 'test'
      end
      jobs[0].user_id.should_not eql jobs[-1].user_id
      jobs = @jobs.by_user_name('user').all
      jobs.length.should eql 0
    end
  
    it "correctly filters by group" do
      jobs = @jobs.by_group_name("root").all
      jobs.length.should eql 25
      jobs[0].user.group.name.should eql "root"
      jobs = @jobs.by_group_name("admin").order(:start_time).all
      jobs.length.should eql 50
      jobs.each do |job|
        job.user.group.name.should eql "admin"
      end
      jobs[0].user.name.should_not eql jobs[1].user.name
      jobs = @jobs.by_group_name("test").all
      jobs.length.should eql 0
    end
    
    it "correctly filters by system" do
      jobs = @jobs.by_system_name('test1')
      jobs.length.should eql 50
      jobs = @jobs.by_system_name('test3')
      jobs.length.should eql 25
    end
    
    it "correctly filters by system type" do
      sys_type = Bookie::Database::SystemType.find_by_name('Standalone')
      jobs = @jobs.by_system_type(sys_type)
    end
    
    it "correctly filters by start time" do
      #To do: expand tests?
      jobs = @jobs.by_start_time_range(@base_time, @base_time + 3600 * 2 + 1)
      jobs.length.should eql 3
      jobs = @jobs.by_start_time_range(@base_time + 1, @base_time + 3600 * 2)
      jobs.length.should eql 1
      jobs = @jobs.by_start_time_range(Time.at(0), Time.at(3))
      jobs.length.should eql 0
    end
    
    it "correctly filters by end time" do
      #To do: expand tests?
      jobs = @jobs.by_end_time_range(@base_time, @base_time + 3600 * 2 + 1)
      jobs.length.should eql 2
      jobs = @jobs.by_end_time_range(@base_time + 1, @base_time + 3600 * 2)
      jobs.length.should eql 1
      jobs = @jobs.by_end_time_range(Time.at(0), Time.at(3))
      jobs.length.should eql 0
    end
    
    it "correctly chains filters" do
      #To do: expand tests?
      jobs = @jobs.by_user_name("test")
      jobs = jobs.by_start_time_range(@base_time + 3600, @base_time + 3601)
      jobs.length.should eql 1
      jobs[0].user.group.name.should eql "default"
    end
    
    describe :each_with_relations do
      it "loads all relations" do
        relations = {}
        Bookie::Database::Job.each_with_relations do |job|
          rels = [job.user, job.user.group, job.system, job.system.system_type]
          rels.each do |r|
            if relations.include?(r)
              old_r = relations[r]
              old_r.should equal r
            end
            relations[r] = r
          end
        end
      end
    end
    
    describe :summary do
      before(:all) do
        @jobs = Bookie::Database::Job
        @summary = @jobs.summary
        @length = @jobs.all.length
      end
      
      it "produces correct totals for jobs" do
        @summary[:jobs].should eql @length
        @summary[:wall_time].should eql @length * 3600
      end
    end
  end
  
  describe Bookie::Database::User do
    describe :find_or_create do
      before(:each) do
        @group = Bookie::Database::Group.find_by_name('admin')
      end
      
      it "creates the user if needed" do
        Bookie::Database::User.expects(:"create!").twice
        user = Bookie::Database::User.find_or_create('me', @group)
        user = Bookie::Database::User.find_or_create('me', @group, {})
      end
      
      it "returns the cached user if one exists" do
        user = Bookie::Database::User.find_by_name('root')
        known_users = {['root', user.group] => user}
        Bookie::Database::User.find_or_create('root', user.group, known_users).should equal user
      end
      
      it "queries the database when this user is not cached" do
        user = Bookie::Database::User.find_by_name_and_group_id('root', 1)
        known_users = {}
        Bookie::Database::User.expects(:find_by_name_and_group_id).returns(user).twice
        Bookie::Database::User.expects(:"create!").never
        Bookie::Database::User.find_or_create('root', user.group, known_users).should eql user
        Bookie::Database::User.find_or_create('root', user.group, nil).should eql user
        known_users.should include ['root', user.group]
      end
    end
  end
  
  describe Bookie::Database::Group do
    describe :find_or_create do
      it "creates the group if needed" do
        Bookie::Database::Group.expects(:"create!")
        group = Bookie::Database::Group.find_or_create('non_root')
      end
      
      it "returns the cached group if one exists" do
        group = Bookie::Database::Group.find_by_name('root')
        known_groups = {'root' => group}
        Bookie::Database::Group.find_or_create('root', known_groups).should equal group
      end
      
      it "queries the database when this group is not cached" do
        group = Bookie::Database::Group.find_by_name('root')
        known_groups = {}
        Bookie::Database::Group.expects(:find_by_name).returns(group).twice
        Bookie::Database::Group.expects(:"create!").never
        Bookie::Database::Group.find_or_create('root', known_groups).should eql group
        Bookie::Database::Group.find_or_create('root', nil).should eql group
        known_groups.should include 'root'
      end
    end
  end
  
  describe Bookie::Database::System do
    it "correctly finds by specifications" do
      sys_type = Bookie::Database::SystemType.find_by_name('Standalone')
      Bookie::Database::System.find_by_specs('test1', sys_type, 2, 1000000).name.should eql 'test1'
      sys_type = Bookie::Database::SystemType.find_by_name('TORQUE cluster')
      Bookie::Database::System.find_by_specs('test1', sys_type, 2, 1000000).should eql nil
    end
    
    it "correctly finds active systems" do
      Bookie::Database::System.active_systems.length.should eql 2
    end
    
    it "correctly filters by name" do
      Bookie::Database::System.by_name('test1').length.should eql 1
    end
  end
end
