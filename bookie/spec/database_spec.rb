require 'spec_helper'

module Helpers
  def self.create_summaries(obj, base_time)
    start_time_1 = base_time
    end_time_1   = base_time + 3600 * 40
    start_time_2 = base_time + 1800
    end_time_2 = base_time + (36000 * 2 + 18000)
    {
      :all => obj.summary,
      :all_constrained => obj.summary(start_time_1, end_time_1),
      :clipped => obj.summary(start_time_2, end_time_2),
      :empty => obj.summary(Time.at(0), Time.at(0)),
    }
  end
  
  def test_relations(job, relations)
    rels = [job.user, job.user.group, job.system, job.system.system_type]
    rels.each do |r|
      if relations.include?(r)
        old_r = relations[r]
        old_r.should eql r
      end
      relations[r] = r
    end
  end
end

describe Bookie::Database do
  before(:all) do
    unless @generated
      Bookie::Database::Migration.up
      Helpers::generate_database
      @generated = true
    end
  end
  
  after(:all) do
    Bookie::Database::Migration.down
  end
  
  describe Bookie::Database::Lock do
    it "finds locks" do
      Lock = Bookie::Database::Lock
      Lock[:users].should_not eql nil
      Lock[:users].name.should eql 'users'
      Lock[:groups].should_not eql nil
      Lock[:groups].name.should eql 'groups'
      expect { Lock[:dummy] }.to raise_error("Unable to find lock 'dummy'")
    end
    
    it "locks records (will probably fail if the testing DB doesn't support row locks)" do
      lock = Bookie::Database::Lock[:users]
      thread = nil
      lock.synchronize do
        thread = Thread.new {
          t = Time.now
          ActiveRecord::Base.connection_pool.with_connection do
            lock.synchronize do
              Bookie::Database::User.first
            end
          end
          (Time.now - t).should >= 0.5
        }
        sleep(1)
      end
      thread.join
    end
    
    it "validates fields" do
      lock = Bookie::Database::Lock.new
      lock.name = nil
      lock.valid?.should eql false
      lock.name = ''
      lock.valid?.should eql false
      lock.name = 'test'
      lock.valid?.should eql true
    end
  end
  
  describe Bookie::Database::Job do
    before(:each) do
      @jobs = Bookie::Database::Job
      @base_time = @jobs.first.start_time
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
      job.start_time = job.start_time + 1
      job.save!
    end
    
    it "correctly filters by user" do
      jobs = @jobs.by_user_name('root').all
      jobs.length.should eql 10
      jobs[0].user.name.should eql "root"
      jobs = @jobs.by_user_name('test').order(:end_time).all
      jobs.length.should eql 20
      jobs.each do |job|
        job.user.name.should eql 'test'
      end
      jobs[0].user_id.should_not eql jobs[-1].user_id
      jobs = @jobs.by_user_name('user').all
      jobs.length.should eql 0
    end
  
    it "correctly filters by group" do
      jobs = @jobs.by_group_name("root").all
      jobs.length.should eql 10
      jobs.each do |job|
        job.user.group.name.should eql "root"
      end
      jobs = @jobs.by_group_name("admin").order(:start_time).all
      jobs.length.should eql 20
      jobs[0].user.name.should_not eql jobs[1].user.name
      jobs = @jobs.by_group_name("test").all
      jobs.length.should eql 0
    end
    
    it "correctly filters by system" do
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
    
    it "correctly filters by start time" do
      jobs = @jobs.by_start_time_range(@base_time, @base_time + 3600 * 2 + 1)
      jobs.length.should eql 3
      jobs = @jobs.by_start_time_range(@base_time + 1, @base_time + 3600 * 2)
      jobs.length.should eql 1
      jobs = @jobs.by_start_time_range(Time.at(0), Time.at(3))
      jobs.length.should eql 0
    end
    
    it "correctly filters by end time" do
      jobs = @jobs.by_end_time_range(@base_time, @base_time + 3600 * 2 + 1)
      jobs.length.should eql 2
      jobs = @jobs.by_end_time_range(@base_time + 1, @base_time + 3600 * 2)
      jobs.length.should eql 1
      jobs = @jobs.by_end_time_range(Time.at(0), Time.at(3))
      jobs.length.should eql 0
    end
    
    it "correctly filters by inclusive time range" do
      jobs = @jobs.by_time_range_inclusive(@base_time, @base_time + 3600 * 2 + 1)
      jobs.length.should eql 3
      jobs = @jobs.by_time_range_inclusive(@base_time + 1, @base_time + 3600 * 2 - 1)
      jobs.length.should eql 2
      jobs = @jobs.by_time_range_inclusive(Time.at(0), Time.at(3))
      jobs.length.should eql 0
      expect {
        @jobs.by_time_range_inclusive(Time.local(2012), Time.local(2012) - 1)
      }.to raise_error('Max time must be greater than or equal to min time')
    end
    
    it "correctly chains filters" do
      jobs = @jobs.by_user_name("test")
      jobs = jobs.by_start_time_range(@base_time + 3600, @base_time + 3601)
      jobs.length.should eql 1
      jobs[0].user.group.name.should eql "default"
    end
    
    describe "::each_with_relations" do
      it "loads all relations" do
        jobs = Bookie::Database::Job.limit(5)
        relations = {}
        jobs.each_with_relations do |job|
          test_relations(job, relations)
        end
        relations = {}
        jobs = jobs.all
        Bookie::Database::Job.each_with_relations(jobs) do |job|
          test_relations(job, relations)
        end
      end
    end
    
    describe "::summary" do
      before(:all) do
        Time.expects(:now).returns(Time.local(2012) + 36000 * 4).at_least_once
        @base_time = Time.local(2012)
        @jobs = Bookie::Database::Job
        @length = @jobs.all.length
        @summary = Helpers::create_summaries(@jobs, Time.local(2012))
      end
      
      it "produces correct summary totals" do
        @summary[:all][:jobs].length.should eql @length
        @summary[:all][:wall_time].should eql @length * 3600
        @summary[:all][:cpu_time].should eql @length * 100
        @summary[:all][:memory_time].should eql @length * 200 * 3600
        @summary[:all][:successful].should eql 0.5
        @summary[:all_constrained][:jobs].length.should eql @length
        @summary[:all_constrained][:wall_time].should eql @length * 3600
        @summary[:all_constrained][:cpu_time].should eql @length * 100
        @summary[:all_constrained][:successful].should eql 0.5
        clipped_jobs = @summary[:clipped][:jobs].length
        clipped_jobs.should eql 25
        @summary[:clipped][:wall_time].should eql clipped_jobs * 3600 - 1800
        @summary[:clipped][:cpu_time].should eql clipped_jobs * 100 - 50
        @summary[:clipped][:memory_time].should eql clipped_jobs * 200 * 3600 - 100 * 3600
      end
      
      it "correctly handles summaries of empty sets" do
        @summary[:empty].should eql({
            :jobs => [],
            :wall_time => 0,
            :cpu_time => 0,
            :memory_time => 0,
            :successful => 0.0,
          })
      end
      
      it "correctly handles jobs with zero wall time" do
        job = @jobs.order(:start_time).first
        wall_time = job.wall_time
        begin
          job.wall_time = 0
          job.save!
          @jobs.order(:start_time).limit(1).summary[:wall_time].should eql 0
        ensure
          job.wall_time = wall_time
          job.save!
        end
      end
      
      it "validates arguments" do
        expect {
          @jobs.summary(Time.local(2012), nil)
        }.to raise_error('Max time must be specified with min time')
        expect {
          @jobs.summary(Time.local(2012), Time.local(2012) - 1)
        }.to raise_error('Max time must be greater than or equal to min time')
      end
    end
    
    it "validates fields" do
      fields = {
        :user => Bookie::Database::User.first,
        :system => Bookie::Database::System.first,
        :cpu_time => 100,
        :start_time => Time.local(2012),
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
      
      job = Bookie::Database::Job.new(fields)
      job.start_time = 0
      job.valid?.should eql false
    end
  end
  
  describe Bookie::Database::User do
    describe "::find_or_create" do
      before(:each) do
        @group = Bookie::Database::Group.find_by_name('admin')
      end
      
      it "creates the user if needed" do
        Bookie::Database::User.expects(:"create!").twice
        user = Bookie::Database::User.find_or_create!('me', @group)
        user = Bookie::Database::User.find_or_create!('me', @group, {})
      end
      
      it "returns the cached user if one exists" do
        user = Bookie::Database::User.find_by_name('root')
        known_users = {['root', user.group] => user}
        Bookie::Database::User.find_or_create!('root', user.group, known_users).should equal user
      end
      
      it "queries the database when this user is not cached" do
        user = Bookie::Database::User.find_by_name_and_group_id('root', 1)
        known_users = {}
        Bookie::Database::User.expects(:find_by_name_and_group_id).returns(user).twice
        Bookie::Database::User.expects(:"create!").never
        Bookie::Database::User.find_or_create!('root', user.group, known_users).should eql user
        Bookie::Database::User.find_or_create!('root', user.group, nil).should eql user
        known_users.should include ['root', user.group]
      end
    end
    
    it "validates fields" do
      fields = {
        :group => Bookie::Database::Group.first,
        :name => 'test',
      }
      
      Bookie::Database::User.new(fields).valid?.should eql true
      
      fields.each_key do |field|
        user = Bookie::Database::User.new(fields)
        user.method("#{field}=".intern).call(nil)
        user.valid?.should eql false
      end
      
      user = Bookie::Database::User.new(fields)
      user.name = ''
      user.valid?.should eql false
    end
  end
  
  describe Bookie::Database::Group do
    describe "::find_or_create" do
      it "creates the group if needed" do
        Bookie::Database::Group.expects(:"create!")
        Bookie::Database::Group.find_or_create!('non_root')
      end
      
      it "returns the cached group if one exists" do
        group = Bookie::Database::Group.find_by_name('root')
        known_groups = {'root' => group}
        Bookie::Database::Group.find_or_create!('root', known_groups).should equal group
      end
      
      it "queries the database when this group is not cached" do
        group = Bookie::Database::Group.find_by_name('root')
        known_groups = {}
        Bookie::Database::Group.expects(:find_by_name).returns(group).twice
        Bookie::Database::Group.expects(:"create!").never
        Bookie::Database::Group.find_or_create!('root', known_groups).should eql group
        Bookie::Database::Group.find_or_create!('root', nil).should eql group
        known_groups.should include 'root'
      end
    end
    
    it "validates the name field" do
      group = Bookie::Database::Group.new(:name => nil)
      group.valid?.should eql false
      group.name = ''
      group.valid?.should eql false
      group.name = 'test'
      group.valid?.should eql true
    end
  end
  
  describe Bookie::Database::System do
    it "correctly finds active systems" do
      Bookie::Database::System.active_systems.length.should eql 3
    end
    
    it "correctly filters by name" do
      Bookie::Database::System.by_name('test1').length.should eql 2
      Bookie::Database::System.by_name('test2').length.should eql 1
      Bookie::Database::System.by_name('test3').length.should eql 1
    end
    
    it "correctly filters by system type" do
      ['Standalone', 'TORQUE cluster'].each do |type|
        t = Bookie::Database::SystemType.find_by_name(type)
        Bookie::Database::System.by_system_type(t).length.should eql 2
      end
    end
    
    describe "::summary" do
      before(:all) do
        Time.expects(:now).returns(Time.local(2012) + 3600 * 40).at_least_once
        @base_time = Time.local(2012)
        @systems = Bookie::Database::System
        @summary = Helpers::create_summaries(@systems, Time.local(2012))
        @summary_wide = @systems.summary(Time.local(2012) - 3600, Time.local(2012) + 3600 * 40 + 3600)
      end
      
      it "produces correct summaries" do
        system_total_wall_time = 3600 * (10 + 30 + 20 + 10)
        system_clipped_wall_time = 3600 * (10 + 15 + 5) - 1800
        system_wide_wall_time = system_total_wall_time + 3600 * 3
        system_total_cpu_time = system_total_wall_time * 2
        clipped_cpu_time = system_clipped_wall_time * 2
        system_wide_cpu_time = system_wide_wall_time * 2
        avg_mem = Float(1000000 * system_total_wall_time / (3600 * 40))
        clipped_avg_mem = Float(1000000 * system_clipped_wall_time) / (3600 * 25 - 1800)
        wide_avg_mem = Float(1000000 * system_wide_wall_time) / (3600 * 42)
        @summary[:all][:avail_cpu_time].should eql system_total_cpu_time
        @summary[:all][:avail_memory_time].should eql 1000000 * system_total_wall_time
        @summary[:all][:avail_memory_avg].should eql avg_mem
        @summary[:all_constrained][:avail_cpu_time].should eql system_total_cpu_time
        @summary[:all_constrained][:avail_memory_time].should eql 1000000 * system_total_wall_time
        @summary[:all_constrained][:avail_memory_avg].should eql avg_mem
        @summary[:clipped][:avail_cpu_time].should eql clipped_cpu_time
        @summary[:clipped][:avail_memory_time].should eql system_clipped_wall_time * 1000000
        @summary[:clipped][:avail_memory_avg].should eql clipped_avg_mem
        @summary_wide[:avail_cpu_time].should eql system_wide_cpu_time
        @summary_wide[:avail_memory_time].should eql 1000000 * system_wide_wall_time
        @summary_wide[:avail_memory_avg].should eql wide_avg_mem
        @summary[:empty][:avail_cpu_time].should eql 0
        @summary[:empty][:avail_memory_time].should eql 0
        @summary[:empty][:avail_memory_avg].should eql 0.0
        begin
          @systems.all.each do |system|
            unless system.id == 1
              system.end_time = Time.now
              system.save!
            end
          end
          summary_all_systems_ended = @systems.summary()
          summary_all_systems_ended.should eql @summary[:all]
          summary_all_systems_ended = @systems.summary(Time.local(2012), Time.now + 3600)
          s2 = @summary[:all].dup
          s2[:avail_memory_avg] = Float(1000000 * system_total_wall_time) / (3600 * 41)
          summary_all_systems_ended.should eql s2
        ensure
          @systems.all.each do |system|
            unless system.id == 1
              system.end_time = nil
              system.save!
            end
          end
        end
      end
      
      it "validates arguments" do
        expect {
          @systems.summary(Time.local(2012), nil)
        }.to raise_error('Max time must be specified with min time')
        expect {
          @systems.summary(Time.local(2012), Time.local(2012) - 1)
        }.to raise_error('Max time must be greater than or equal to min time')
      end
    end
    
    it "correctly creates systems when they don't exist" do
      Bookie::Database::System.expects(:"create!")
      Bookie::Database::System.find_active_by_name_or_create!(:name => "abc")
    end

    describe "::find_active_by_name_or_create!" do
      before(:all) do
        @FIELDS = {
          :name => 'test',
          :start_time => Time.local(2012),
          :system_type => Bookie::Database::SystemType.first,
          :cores => 2,
          :memory => 1000000
        }
      end
      
      it "correctly creates systems when only old versions exist" do
        create_fields = @FIELDS.dup
        create_fields[:end_time] = Time.local(2012) + 1
        sys = Bookie::Database::System.create!(create_fields)
        begin
          Bookie::Database::System.expects(:"create!")
          Bookie::Database::System.find_active_by_name_or_create!(@FIELDS)
        ensure
          sys.delete
        end
      end
  
      it "uses the existing active system" do
        sys = Bookie::Database::System.create!(@FIELDS)
        begin
          Bookie::Database::System.expects(:"create!").never
          Bookie::Database::System.find_active_by_name_or_create!(@FIELDS)
        ensure
          sys.delete
        end
      end
      
      it "correctly detects conflicts" do
        fields = @FIELDS.dup
        fields[:cores] = 1
        csys = Bookie::Database::System.create!(fields)
        begin
          expect {
            Bookie::Database::System.find_active_by_name_or_create!(@FIELDS)
          }.to raise_error(Bookie::Database::System::SystemConflictError)
        ensure
          csys.delete
        end
      end
    end

    it "correctly decommissions" do
      sys = Bookie::Database::System.active_systems.find_by_name('test1')
      begin
        sys.decommission(sys.start_time + 3)
        sys.end_time.should eql sys.start_time + 3
      ensure
        sys.end_time = nil
        sys.save!
      end
    end
    
    it "validates fields" do
      fields = {
        :name => 'test',
        :cores => 2,
        :memory => 1000000,
        :system_type => Bookie::Database::SystemType.first,
        :start_time => Time.local(2012)
      }
      
      Bookie::Database::System.new(fields).valid?.should eql true
      
      fields.each_key do |field|
        system = Bookie::Database::System.new(fields)
        system.method("#{field}=".intern).call(nil)
        system.valid?.should eql false
      end
      
      system = Bookie::Database::System.new(fields)
      system.name = ''
      system.valid?.should eql false
      
      [:cores, :memory].each do |field|
        system = Bookie::Database::System.new(fields)
        m = system.method("#{field}=".intern)
        m.call(-1)
        system.valid?.should eql false
        m.call(0)
        system.valid?.should eql true
      end
      
      system = Bookie::Database::System.new(fields)
      system.start_time = 0
      system.valid?.should eql false
      
      system = Bookie::Database::System.new(fields)
      system.end_time = Time.local(2012)
      system.valid?.should eql true
      system.end_time += 5
      system.valid?.should eql true
      system.end_time -= 10
      system.valid?.should eql false
    end
  end
  
  describe Bookie::Database::SystemType do
    it "correctly maps memory stat type codes to/from symbols" do
      systype = Bookie::Database::SystemType.new
      systype.memory_stat_type = :avg
      systype.memory_stat_type.should eql :avg
      systype.read_attribute(:memory_stat_type).should eql Bookie::Database::MEMORY_STAT_TYPE[:avg]
      systype.memory_stat_type = :max
      systype.memory_stat_type.should eql :max
      systype.read_attribute(:memory_stat_type).should eql Bookie::Database::MEMORY_STAT_TYPE[:max]
    end
    
    it "rejects unrecognized memory stat type codes" do
      systype = Bookie::Database::SystemType.new
      expect { systype.memory_stat_type = :invalid_type }.to raise_error("Unrecognized memory stat type 'invalid_type'")
      expect { systype.memory_stat_type = nil }.to raise_error 'Memory stat type must not be nil'
      systype.send(:write_attribute, :memory_stat_type, 10000)
      expect { systype.memory_stat_type }.to raise_error("Unrecognized memory stat type code 10000")
    end
    
    it "creates the system type when needed" do
      Bookie::Database::SystemType.expects(:'create!')
      Bookie::Database::SystemType.find_or_create!('test', :avg)
    end
    
    it "raises an error if the existing type has the wrong memory stat type" do
      systype = Bookie::Database::SystemType.create!(:name => 'test', :memory_stat_type => :max)
      begin
        expect {
          Bookie::Database::SystemType.find_or_create!('test', :avg)
        }.to raise_error("The recorded memory stat type for system type 'test' does not match the required type of 1")
        expect {
          Bookie::Database::SystemType.find_or_create!('test', :unrecognized)
        }.to raise_error("Unrecognized memory stat type 'unrecognized'")
      ensure
        systype.delete
      end
    end
    
    it "uses the existing type" do
      systype = Bookie::Database::SystemType.create!(:name => 'test', :memory_stat_type => :avg)
      begin
        Bookie::Database::SystemType.expects(:'create!').never
        Bookie::Database::SystemType.find_or_create!('test', :avg)
      ensure
        systype.delete
      end
    end
    
    it "validates fields" do
      systype = Bookie::Database::SystemType.new(:name => 'test')
      expect { systype.valid? }.to raise_error('Memory stat type must not be nil')
      systype.memory_stat_type = :unknown
      systype.valid?.should eql true
      systype.name = nil
      systype.valid?.should eql false
      systype.name = ''
      systype.valid?.should eql false
    end
  end
end
