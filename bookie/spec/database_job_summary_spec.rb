require 'spec_helper'

describe Bookie::Database::JobSummary do
  before(:all) do
    d = Date.new(2012)
    Bookie::Database::User.find_each do |user|
      Bookie::Database::System.find_each do |system|
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
    sums = Bookie::Database::JobSummary.by_date(d).to_a
    expect(sums.length).to eql 32
    sums.each do |sum|
      expect(sum.date).to eql d
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
    sums = Bookie::Database::JobSummary.by_user(u).to_a
    sums.length.should eql 16
    sums.each do |sum|
      sum.user.should eql u
    end
  end
  
  it "correctly filters by user name" do
    sums = Bookie::Database::JobSummary.by_user_name('test').to_a
    sums.length.should eql 32
    sums.each do |sum|
      sum.user.name.should eql 'test'
    end
  end
  
  it "correctly filters by group" do
    g = Bookie::Database::Group.find_by_name('admin')
    sums = Bookie::Database::JobSummary.by_group(g).to_a
    sums.length.should eql 32
    sums.each do |sum|
      sum.user.group.should eql g
    end
  end
  
  it "correctly filters by group name" do
    sums = Bookie::Database::JobSummary.by_group_name('admin').to_a
    sums.length.should eql 32
    sums.each do |sum|
      sum.user.group.name.should eql 'admin'
    end
    Bookie::Database::JobSummary.by_group_name('fake_group').count.should eql 0
  end
  
  it "correctly filters by system" do
    s = Bookie::Database::System.first
    sums = Bookie::Database::JobSummary.by_system(s).to_a
    sums.length.should eql 16
    sums.each do |sum|
      sum.system.should eql s
    end
  end
  
  it "correctly filters by system name" do
    sums = Bookie::Database::JobSummary.by_system_name('test1').to_a
    sums.length.should eql 32
    sums.each do |sum|
      sum.system.name.should eql 'test1'
    end
  end
  
  it "correctly filters by system type" do
    s = Bookie::Database::SystemType.first
    sums = Bookie::Database::JobSummary.by_system_type(s).to_a
    sums.length.should eql 32
    sums.each do |sum|
      sum.system.system_type.should eql s
    end
  end
  
  it "correctly filters by command name" do
    sums = Bookie::Database::JobSummary.by_command_name('vi').to_a
    sums.length.should eql 32
    sums.each do |sum|
      sum.command_name.should eql 'vi'
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
      sums = Bookie::Database::JobSummary.all.to_a
      found_sums = Set.new
      sums.each do |sum|
        sum.date.should eql Date.new(2012)
        jobs = Bookie::Database::Job.by_user(sum.user).by_system(sum.system).by_command_name(sum.command_name)
        sum_2 = jobs.summary(range)
        [:cpu_time, :memory_time].each do |field|
          expect(sum.send(field)).to eql(sum_2[field])
        end
        found_sums.add([sum.user.id, sum.system.id, sum.command_name])
      end
      #Is it catching all of the combinations of categories?
      Bookie::Database::Job.by_time_range(range).select('user_id, system_id, command_name').uniq.find_each do |values|
        values = [values.user_id, values.system_id, values.command_name]
        found_sums.include?(values).should eql true
      end
    end
    
    it "creates dummy summaries when there are no jobs" do
      d = Date.new(2012) + 5
      Bookie::Database::JobSummary.summarize(d)
      sums = Bookie::Database::JobSummary.by_date(d).to_a
      sums.length.should eql 1
      sum = sums[0]
      sum.cpu_time.should eql 0
      sum.memory_time.should eql 0

      #Check the case where there are no users or no systems:
      Bookie::Database::JobSummary.delete_all
      [Bookie::Database::User, Bookie::Database::System].each do |klass|
        Bookie::Database::JobSummary.transaction(:requires_new => true) do
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
      1.upto(3) do |num_days|
        [0, -7200, 7200].each do |offset_begin|
          [0, -7200, 7200].each do |offset_end|
            [true, false].each do |exclude_end|
              range_offset = Range.new(base_time + offset_begin, base_time + num_days.days + offset_end, exclude_end)
              sum1 = Bookie::Database::JobSummary.summary(:range => range_offset)
              sum2 = Bookie::Database::Job.summary(range_offset)
              expect(sum1).to eql(sum2)
            end
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
      expect(Bookie::Database::JobSummary.summary).to eql(Bookie::Database::Job.summary)
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
      #Check the case where there are no systems.
      #Stub out methods of System's "Relation" class:
      Bookie::Database::System.where('1=1').class.any_instance.expects(:'any?').at_least_once.returns(false)
      Bookie::Database::System.where('1=1').class.any_instance.expects(:first).at_least_once.returns(nil)
      sum = Bookie::Database::JobSummary.summary
      sum.should eql({
        :num_jobs => 0,
        :cpu_time => 0,
        :memory_time => 0,
        :successful => 0,
      })
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
        expect(sum1).to eql(sum2)
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
      Bookie::Database::JobSummary.expects(:summarize)
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

