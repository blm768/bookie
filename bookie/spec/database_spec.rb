require 'spec_helper'

module Helpers
  def self.create_summaries(obj, base_time)
    start_time_1 = base_time
    end_time_1   = base_time + 3600 * 40
    start_time_2 = base_time + 1800
    end_time_2 = base_time + (36000 * 2 + 18000)
    summaries = {
      :all => obj.summary,
      :all_constrained => obj.summary(start_time_1 ... end_time_1),
      :clipped => obj.summary(start_time_2 ... end_time_2),
      :empty => obj.summary(Time.at(0) ... Time.at(0)),
    }
    if obj.respond_to?(:by_command_name)
      summaries[:all_filtered] = obj.by_command_name('vi').summary(start_time_1 ... end_time_1)
    end
    
    summaries
  end
  
  def test_job_relations(job, relations)
    #Make sure all relations with the same value have the same object_id:
    rels = [job.user, job.user.group, job.system, job.system.system_type]
    unbound_object_id = Object.instance_method(:object_id)
    rels.each do |r|
      if relations.include?(r)
        relations[r].should eql unbound_object_id.bind(r).call
      else
        relations[r] = unbound_object_id.bind(r).call
      end
    end
  end

  def test_system_relations(system, relations)
    t = system.system_type
    unbound_object_id = Object.instance_method(:object_id)
    if relations.include?(t)
      relations[t].should eql unbound_object_id.bind(t).call
    else
      relations[t] = unbound_object_id.bind(t).call
    end
  end

  
  def check_job_sums(js_sum, j_sum)
    [:cpu_time, :memory_time].each do |field|
      js_sum[field].should eql j_sum[field]
    end
    true
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
    
    it "locks records (will probably fail if the testing DB doesn't support row locks)" #do
      #lock = Bookie::Database::Lock[:users]
      #thread = nil
      #lock.synchronize do
      #  thread = Thread.new {
      #    t = Time.now
      #    ActiveRecord::Base.connection_pool.with_connection do
      #      lock.synchronize do
      #        Bookie::Database::User.first
      #      end
      #    end
      #    (Time.now - t).should >= 0.5
      #  }
      #  sleep(1)
      #end
      #thread.join
    #end
    
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
      user = Bookie::Database::User.by_name('test').order(:id).first
      jobs = @jobs.by_user(user).all
      jobs.each do |job|
        job.user.should eql user
      end
      jobs.length.should eql 10 
    end
    
    it "correctly filters by user name" do
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
  
    it "correctly filters by group name" do
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
    
    describe "#by_time_range_inclusive" do
      it "correctly filters by inclusive time range" do
        jobs = @jobs.by_time_range_inclusive(base_time ... base_time + 3600 * 2 + 1)
        jobs.count.should eql 3
        jobs = @jobs.by_time_range_inclusive(base_time + 1 ... base_time + 3600 * 2)
        jobs.count.should eql 2
        jobs = @jobs.by_time_range_inclusive(base_time ... base_time)
        jobs.length.should eql 0
        jobs = @jobs.by_time_range_inclusive(base_time .. base_time + 3600 * 2)
        jobs.count.should eql 3
        jobs = @jobs.by_time_range_inclusive(base_time .. base_time)
        jobs.count.should eql 1
      end
      
      it "correctly handles empty/inverted ranges" do
        t = base_time
        (-1 .. 0).each do |offset|
          jobs = @jobs.by_time_range_inclusive(t ... t + offset)
          jobs.count.should eql 0
        end
      end
    end
    
    it "correctly chains filters" do
      jobs = @jobs.by_user_name("test")
      jobs = jobs.by_start_time_range(base_time + 3600 ... base_time + 3601)
      jobs.length.should eql 1
      jobs[0].user.group.name.should eql "default"
    end
    
    describe "#all_with_relations" do
      it "loads all relations" do
        jobs = Bookie::Database::Job.limit(5)
        relations = {}
        jobs = jobs.all_with_relations
        Bookie::Database::User.expects(:new).never
        Bookie::Database::Group.expects(:new).never
        Bookie::Database::System.expects(:new).never
        Bookie::Database::SystemType.expects(:new).never
        jobs.each do |job|
          test_job_relations(job, relations)
        end
      end
    end
    
    describe "#summary" do
      before(:all) do
        Time.expects(:now).returns(base_time + 36000 * 4).at_least_once
        @jobs = Bookie::Database::Job
        @length = @jobs.all.length
        @summary = Helpers::create_summaries(@jobs, base_time)
      end
      
      it "produces correct summary totals" do
        @summary[:all][:jobs].length.should eql @length
        @summary[:all][:cpu_time].should eql @length * 100
        @summary[:all][:memory_time].should eql @length * 200 * 3600
        @summary[:all][:successful].should eql 20
        @summary[:all_constrained][:jobs].length.should eql @length
        @summary[:all_constrained][:cpu_time].should eql @length * 100
        @summary[:all_constrained][:successful].should eql 20
        @summary[:all_filtered][:jobs].length.should eql @length / 2
        @summary[:all_filtered][:cpu_time].should eql @length * 100 / 2
        @summary[:all_filtered][:successful].should eql 20
        clipped_jobs = @summary[:clipped][:jobs].length
        clipped_jobs.should eql 25
        @summary[:clipped][:cpu_time].should eql clipped_jobs * 100 - 50
        @summary[:clipped][:memory_time].should eql clipped_jobs * 200 * 3600 - 100 * 3600
        @summary[:clipped][:successful].should eql clipped_jobs / 2 + 1
      end
      
      it "correctly handles summaries of empty sets" do
        @summary[:empty].should eql({
            :jobs => [],
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
        sum[:jobs].length.should eql 1
        sum = @jobs.summary(base_time .. base_time + 3600)
        sum[:jobs].length.should eql 2
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
  
  describe Bookie::Database::JobSummary do
  
    describe "" do
      before(:all) do
        d = Date.new(2012)
        Bookie::Database::User.all.each do |user|
          Bookie::Database::System.all.each do |system|
            ['vi', 'emacs'].each do |command_name|
              (d ... d + 2).each do |date|
                Bookie::Database::JobSummary.create!(
                  :user => user,
                  :system => system,
                  :command_name => command_name,
                  :date => date,
                  :cpu_time => 0,
                  :memory_time => 0,
                  :successful => 0
                )
              end
            end
          end
        end
      end
      
      it "correctly filters by date" do
        d = Date.new(2012)
        sums = Bookie::Database::JobSummary.by_date(d).all
        sums.length.should eql 32
        sums.each do |sum|
          sum.date.should eql d
        end
      end

      it "correctly filters by date range" do
        d = Date.new(2012)
        sums = Bookie::Database::JobSummary
        sums.by_date_range(d .. d).count.should eql sums.by_date(d).count
        sums.by_date_range(d ... d).count.should eql 0
        sums.by_date_range(d + 1 .. d).count.should eql 0
        sums.by_date_range(d .. d + 1).count.should eql sums.by_date(d).count + sums.by_date(d + 1).count
        sums.by_date_range(d ... d + 1).count.should eql sums.by_date(d).count
      end
      
      it "correctly filters by user" do
        u = Bookie::Database::User.first
        sums = Bookie::Database::JobSummary.by_user(u).all
        sums.length.should eql 16
        sums.each do |sum|
          sum.user.should eql u
        end
      end
      
      it "correctly filters by user name" do
        sums = Bookie::Database::JobSummary.by_user_name('test').all
        sums.length.should eql 32
        sums.each do |sum|
          sum.user.name.should eql 'test'
        end
      end
      
      it "correctly filters by group" do
        g = Bookie::Database::Group.find_by_name('admin')
        sums = Bookie::Database::JobSummary.by_group(g).all
        sums.length.should eql 32
        sums.each do |sum|
          sum.user.group.should eql g
        end
      end
      
      it "correctly filters by group name" do
        sums = Bookie::Database::JobSummary.by_group_name('admin').all
        sums.length.should eql 32
        sums.each do |sum|
          sum.user.group.name.should eql 'admin'
        end
      end
      
      it "correctly filters by system" do
        s = Bookie::Database::System.first
        sums = Bookie::Database::JobSummary.by_system(s).all
        sums.length.should eql 16
        sums.each do |sum|
          sum.system.should eql s
        end
      end
      
      it "correctly filters by system name" do
        sums = Bookie::Database::JobSummary.by_system_name('test1').all
        sums.length.should eql 32
        sums.each do |sum|
          sum.system.name.should eql 'test1'
        end
      end
      
      it "correctly filters by system type" do
        s = Bookie::Database::SystemType.first
        sums = Bookie::Database::JobSummary.by_system_type(s).all
        sums.length.should eql 32
        sums.each do |sum|
          sum.system.system_type.should eql s
        end
      end
      
      it "correctly filters by command name" do
        sums = Bookie::Database::JobSummary.by_command_name('vi').all
        sums.length.should eql 32
        sums.each do |sum|
          sum.command_name.should eql 'vi'
        end
      end
    end
    
    describe "#find_or_new" do
      it "creates a summary if needed" do
        Bookie::Database::JobSummary.delete_all
        s = Bookie::Database::JobSummary.find_or_new(Date.new(2012), 1, 1, 'vi')
        s.persisted?.should eql false
        s.cpu_time = 0
        s.memory_time = 0
        s.save!
      end
      
      it "uses the old summary if present" do
        #Uses the JobSummary created in the previous test
        s = Bookie::Database::JobSummary.find_or_new(Date.new(2012), 1, 1, 'vi')
        s.persisted?.should eql true
      end
    end
    
    describe "#summarize" do
      before(:each) do
        Bookie::Database::JobSummary.delete_all
      end
      
      it "produces correct summaries" do
        d = Date.new(2012)
        range = base_time ... base_time + 1.days
        Bookie::Database::JobSummary.summarize(d)
        sums = Bookie::Database::JobSummary.all
        found_sums = Set.new
        sums.each do |sum|
          sum.date.should eql Date.new(2012)
          jobs = Bookie::Database::Job.by_user(sum.user).by_system(sum.system).by_command_name(sum.command_name)
          sum_2 = jobs.summary(range)
          check_job_sums(sum, sum_2)
          found_sums.add([sum.user.id, sum.system.id, sum.command_name])
        end
        #Is it catching all of the combinations of categories?
        Bookie::Database::Job.by_time_range_inclusive(range).select('user_id, system_id, command_name').uniq.all.each do |values|
          values = [values.user_id, values.system_id, values.command_name]
          found_sums.include?(values).should eql true
        end
      end
      
      it "creates dummy summaries when there are no jobs" do
        d = Date.new(2012) + 5
        Bookie::Database::JobSummary.summarize(d)
        sums = Bookie::Database::JobSummary.by_date(d).all
        sums.length.should eql 1
        sum = sums[0]
        sum.cpu_time.should eql 0
        sum.memory_time.should eql 0

        #Check the case where there are no users or no systems:
        Bookie::Database::JobSummary.delete_all
        [Bookie::Database::User, Bookie::Database::System].each do |klass|
          #This will cause nested transactions, but we *should* be OK.
          Bookie::Database::JobSummary.transaction do
            klass.delete_all
            Bookie::Database::JobSummary.summarize(d)
            Bookie::Database::JobSummary.by_date(d).count.should eql 0
            raise ActiveRecord::Rollback
          end
        end
      end
    end
  
    describe "#summary" do
      before(:each) do
        Bookie::Database::JobSummary.delete_all
        t = base_time + 2.days
        Time.expects(:now).at_least(0).returns(t)
      end
      
      it "produces correct summaries" do
        #To consider: flesh out some more?
        time_start = base_time
        time_end = time_start
        time_bound = time_start + 3.days
        while time_start < time_bound
          while time_end < time_bound
            [true, false].each do |exclude_end|
              time_range = Range.new(time_start, time_end, exclude_end)
              sum1 = Bookie::Database::JobSummary.summary(:range => time_range)
              sum2 = Bookie::Database::Job.summary(time_range)
              check_job_sums(sum1, sum2)
            end
            time_end += 1.days
          end
          time_start += 1.days
        end
        time_start = base_time
        time_end = time_start + 1.days
        [0, -7200, 7200].each do |offset_begin|
          [0, -7200, 7200].each do |offset_end|
            [true, false].each do |exclude_end|
              range_offset = Range.new(time_start + offset_end, time_end + offset_end, exclude_end)
              sum1 = Bookie::Database::JobSummary.summary(:range => range_offset)
              sum2 = Bookie::Database::Job.summary(range_offset)
              check_job_sums(sum1, sum2)
            end
          end
        end
      end

      it "distinguishes between inclusive and exclusive ranges" do
        Summary = Bookie::Database::JobSummary
        sum = Summary.summary(:range => (base_time ... base_time + 3600 * 2))
        sum[:num_jobs].should eql 2
        sum = Summary.summary(:range => (base_time .. base_time + 3600 * 2))
        sum[:num_jobs].should eql 3
      end

      def check_time_bounds(time_max = base_time + 1.days)
        time_min = base_time
        check_job_sums(Bookie::Database::JobSummary.summary, Bookie::Database::Job.summary)
        Bookie::Database::JobSummary.order(:date).first.date.should eql time_min.to_date
        Bookie::Database::JobSummary.order('date DESC').first.date.should eql time_max.utc.to_date
      end
      
      it "correctly finds the default time bounds" do
        #The last daily summary in this range isn't cached because Time.now could be partway through a day.
        check_time_bounds
        systems = Bookie::Database::System.active_systems
        Bookie::Database::JobSummary.delete_all
        #Check the case where all systems are decommissioned.
        end_times = {}
        begin
          systems.each do |sys|
            end_times[sys.id] = sys.end_time
            sys.end_time = base_time + 2.days
            sys.save!
          end
          check_time_bounds
        ensure
          systems.each do |sys|
            sys.end_time = end_times[sys.id]
            sys.save!
          end
        end
        Bookie::Database::JobSummary.delete_all
        empty = Bookie::Database::System.limit(0)
        #Check the case where there are no systems.
        ActiveRecord::Relation.any_instance.expects(:'any?').at_least_once.returns(false)
        ActiveRecord::Relation.any_instance.expects(:first).at_least_once.returns(nil)
        sum = Bookie::Database::JobSummary.summary
        sum.should eql({
          :num_jobs => 0,
          :cpu_time => 0,
          :memory_time => 0,
          :successful => 0,
        })
        ActiveRecord::Relation.any_instance.unstub(:'any?')
        Bookie::Database::JobSummary.any?.should eql false
      end
      
      it "correctly handles filtered summaries" do
        filters = {
          :user_name => 'test',
          :group_name => 'admin',
          :command_name => 'vi',
        }
        filters.each do |filter, value|
          filter_sym = "by_#{filter}".intern
          jobs = Bookie::Database::Job.send(filter_sym, value)
          sum1 = Bookie::Database::JobSummary.send(filter_sym, value).summary(:jobs => jobs)
          sum2 = jobs.summary
          check_job_sums(sum1, sum2)
        end
      end
      
      it "correctly handles inverted ranges" do
        t = base_time
        Bookie::Database::JobSummary.summary(:range => t .. t - 1).should eql({
          :num_jobs => 0,
          :cpu_time => 0,
          :memory_time => 0,
          :successful => 0,
        })
      end
      
      it "caches summaries" do
        Bookie::Database::JobSummary.summary
        Bookie::Database::JobSummary.expects(:summarize).never
        range = base_time ... base_time + 1.days
        Bookie::Database::JobSummary.summary(:range => range)
      end

      it "uses the cached summaries" do
        Bookie::Database::JobSummary.summary
        Bookie::Database::Job.expects(:summary).never
        range = base_time ... base_time + 1.days
        Bookie::Database::JobSummary.summary(:range => range)
      end
    end
    
    it "validates fields" do
      fields = {
        :user => Bookie::Database::User.first,
        :system => Bookie::Database::System.first,
        :command_name => '',
        :date => Date.new(2012),
        :cpu_time => 100,
        :memory_time => 1000000,
      }

      sum = Bookie::Database::JobSummary.new(fields)
      sum.valid?.should eql true
      
      fields.each_key do |field|
        job = Bookie::Database::JobSummary.new(fields)
        job.method("#{field}=".intern).call(nil)
        job.valid?.should eql false
      end
      
      [:cpu_time, :memory_time].each do |field|
        job = Bookie::Database::JobSummary.new(fields)
        m = job.method("#{field}=".intern)
        m.call(-1)
        job.valid?.should eql false
        m.call(0)
        job.valid?.should eql true
      end
    end
  end
  
  describe Bookie::Database::User do
    it "correctly filters by name" do
      users = Bookie::Database::User.by_name('test').all
      users.length.should eql 2
      users.each do |user|
        user.name.should eql 'test'
      end
    end
    
    describe "#find_or_create" do
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
    describe "#find_or_create" do
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
    before(:each) do
      @systems = Bookie::Database::System
    end

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

    describe "#all_with_relations" do
      it "loads all relations" do
        systems = Bookie::Database::System.limit(5)
        relations = {}
        systems = systems.all_with_relations
        Bookie::Database::SystemType.expects(:new).never
        systems.each do |system|
          test_system_relations(system, relations)
        end
      end
    end

    describe "#by_time_range_inclusive" do
      it "correctly filters by inclusive time range" do
        systems = @systems.by_time_range_inclusive(base_time ... base_time + 36000 * 2 + 1)
        systems.count.should eql 3
        systems = @systems.by_time_range_inclusive(base_time + 1 ... base_time + 36000 * 2)
        systems.count.should eql 2
        systems = @systems.by_time_range_inclusive(base_time ... base_time)
        systems.length.should eql 0
        systems = @systems.by_time_range_inclusive(base_time .. base_time + 36000 * 2)
        systems.count.should eql 3
        systems = @systems.by_time_range_inclusive(base_time .. base_time)
        systems.count.should eql 1
      end
      
      it "correctly handles empty/inverted ranges" do
        (-1 .. 0).each do |offset|
          systems = @systems.by_time_range_inclusive(base_time ... base_time + offset)
          systems.count.should eql 0
        end
      end
    end

    describe "#summary" do
      before(:all) do
        Time.expects(:now).returns(base_time + 3600 * 40).at_least_once
        @systems = Bookie::Database::System
        @summary = Helpers::create_summaries(@systems, base_time)
        @summary_wide = @systems.summary(base_time - 3600 ... base_time + 3600 * 40 + 3600)
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
        @summary[:all][:systems].length.should eql 4
        @summary[:all][:avail_cpu_time].should eql system_total_cpu_time
        @summary[:all][:avail_memory_time].should eql 1000000 * system_total_wall_time
        @summary[:all][:avail_memory_avg].should eql avg_mem
        @summary[:all_constrained][:systems].length.should eql 4
        @summary[:all_constrained][:avail_cpu_time].should eql system_total_cpu_time
        @summary[:all_constrained][:avail_memory_time].should eql 1000000 * system_total_wall_time
        @summary[:all_constrained][:avail_memory_avg].should eql avg_mem
        @summary[:clipped][:systems].length.should eql 3
        @summary[:clipped][:avail_cpu_time].should eql clipped_cpu_time
        @summary[:clipped][:avail_memory_time].should eql system_clipped_wall_time * 1000000
        @summary[:clipped][:avail_memory_avg].should eql clipped_avg_mem
        @summary_wide[:systems].length.should eql 4
        @summary_wide[:avail_cpu_time].should eql system_wide_cpu_time
        @summary_wide[:avail_memory_time].should eql 1000000 * system_wide_wall_time
        @summary_wide[:avail_memory_avg].should eql wide_avg_mem
        @summary[:empty][:systems].length.should eql 0
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
          summary_all_systems_ended = @systems.summary(base_time ... Time.now + 3600)
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
      
      it "correctly handles inverted ranges" do
        t = base_time
        @systems.summary(t ... t - 1).should eql @summary[:empty]
        @systems.summary(t .. t - 1).should eql @summary[:empty]
      end
    end

    describe "#find_current" do
      before(:all) do
        @config_t1 = @config.clone
        
        @config_t1.hostname = 'test1'
        @config_t1.system_type = 'standalone'
        @config_t1.cores = 2
        @config_t1.memory = 1000000
        
        @config_t2 = @config_t1.clone
        @config_t2.system_type = 'torque_cluster'
        
        @sender_1 = Bookie::Sender.new(@config_t1)
        @sender_2 = Bookie::Sender.new(@config_t2)
      end

      it "finds the correct system" do
        Bookie::Database::System.find_current(@sender_2).id.should eql 2
        Bookie::Database::System.find_current(@sender_2, Time.now).id.should eql 2
        Bookie::Database::System.find_current(@sender_1, base_time).id.should eql 1
      end
      
      it "correctly detects the lack of a matching system" do
        expect {
          Bookie::Database::System.find_current(@sender_1, base_time - 1.years)
        }.to raise_error(/^There is no system with hostname 'test1' in the database at /)
        @config_t1.expects(:hostname).at_least_once.returns('test1000')
        expect {
          Bookie::Database::System.find_current(@sender_1, base_time)
        }.to raise_error(/^There is no system with hostname 'test1000' in the database at /)
      end
      
      it "correctly detects conflicts" do
        config = @config.clone
        config.hostname = 'test1'
        config.cores = 2
        config.memory = 1000000

        sender = Bookie::Sender.new(config)
        [:cores, :memory].each do |field|
          config.expects(field).at_least_once.returns("value")
          expect {
            Bookie::Database::System.find_current(sender)
          }.to raise_error(Bookie::Database::System::SystemConflictError)
          config.unstub(field)
        end
        sender.expects(:system_type).returns(Bookie::Database::SystemType.find_by_name("Standalone"))
        expect {
          Bookie::Database::System.find_current(sender)
        }.to raise_error(Bookie::Database::System::SystemConflictError)
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
        :start_time => base_time
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
      system.end_time = base_time
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

