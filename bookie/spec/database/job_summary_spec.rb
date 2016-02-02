require 'spec_helper'

require 'bookie/database/job_summary'

include Bookie::Database

describe Bookie::Database::JobSummary do
  #TODO: only do this for the finder methods.
  before(:all) do
    d = Date.new(2012)
    User.find_each do |user|
      System.find_each do |system|
        ['vi', 'emacs'].each do |command_name|
          (d ... d + 2).each do |date|
            JobSummary.create!(
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
    sums = JobSummary.by_date(d).to_a
    expect(sums.length).to eql 32
    sums.each do |sum|
      expect(sum.date).to eql d
    end
  end

  it "correctly filters by date range" do
    d = Date.new(2012)
    sums = JobSummary
    expect(sums.by_date_range(d .. d).count).to eql sums.by_date(d).count
    expect(sums.by_date_range(d ... d).count).to eql 0
    expect(sums.by_date_range(d + 1 .. d).count).to eql 0
    expect(sums.by_date_range(d .. d + 1).count).to eql sums.by_date(d).count + sums.by_date(d + 1).count
    expect(sums.by_date_range(d ... d + 1).count).to eql sums.by_date(d).count
  end

  it "correctly filters by user" do
    u = User.first
    sums = JobSummary.by_user(u).to_a
    expect(sums.length).to eql 16
    sums.each do |sum|
      expect(sum.user).to eql u
    end
  end

  it "correctly filters by user name" do
    sums = JobSummary.by_user_name('test').to_a
    expect(sums.length).to eql 32
    sums.each do |sum|
      expect(sum.user.name).to eql 'test'
    end
  end

  it "correctly filters by group" do
    g = Group.find_by_name('admin')
    sums = JobSummary.by_group(g).to_a
    expect(sums.length).to eql 32
    sums.each do |sum|
      expect(sum.user.group).to eql g
    end
  end

  it "correctly filters by group name" do
    sums = JobSummary.by_group_name('admin').to_a
    expect(sums.length).to eql 32
    sums.each do |sum|
      expect(sum.user.group.name).to eql 'admin'
    end
    expect(JobSummary.by_group_name('fake_group').count).to eql 0
  end

  it "correctly filters by system" do
    s = System.first
    sums = JobSummary.by_system(s).to_a
    expect(sums.length).to eql 16
    sums.each do |sum|
      expect(sum.system).to eql s
    end
  end

  it "correctly filters by system name" do
    sums = JobSummary.by_system_name('test1').to_a
    expect(sums.length).to eql 32
    sums.each do |sum|
      expect(sum.system.name).to eql 'test1'
    end
  end

  it "correctly filters by system type" do
    s = SystemType.first
    sums = JobSummary.by_system_type(s).to_a
    expect(sums.length).to eql 32
    sums.each do |sum|
      expect(sum.system.system_type).to eql s
    end
  end

  it "correctly filters by command name" do
    sums = JobSummary.by_command_name('vi').to_a
    expect(sums.length).to eql 32
    sums.each do |sum|
      expect(sum.command_name).to eql 'vi'
    end
  end

  describe "#summarize" do
    before(:each) do
      JobSummary.delete_all
    end

    it "produces correct summaries" do
      d = Date.new(2012)
      range = base_time ... base_time + 1.days
      JobSummary.summarize(d)
      sums = JobSummary.all.to_a
      found_sums = Set.new
      sums.each do |sum|
        expect(sum.date).to eql Date.new(2012)
        jobs = Job.by_user(sum.user).by_system(sum.system).by_command_name(sum.command_name)
        sum_2 = jobs.summary(range)
        [:cpu_time, :memory_time].each do |field|
          expect(sum.send(field)).to eql(sum_2[field])
        end
        found_sums.add([sum.user.id, sum.system.id, sum.command_name])
      end
      #Is it catching all of the combinations of categories?
      Job.by_time_range(range).select(:id, :user_id, :system_id, :command_name).uniq.find_each do |values|
        values = [values.user_id, values.system_id, values.command_name]
        expect(found_sums.include?(values)).to eql true
      end
    end

    it "creates dummy summaries when there are no jobs" do
      d = Date.new(2012) + 5
      JobSummary.summarize(d)
      sums = JobSummary.by_date(d).to_a
      expect(sums.length).to eql 1
      sum = sums[0]
      expect(sum.cpu_time).to eql 0
      expect(sum.memory_time).to eql 0

      #Check the case where there are no users or no systems:
      JobSummary.delete_all
      [User, System].each do |klass|
        JobSummary.transaction(:requires_new => true) do
          klass.delete_all
          JobSummary.summarize(d)
          expect(JobSummary.by_date(d).count).to eql 0
          raise ActiveRecord::Rollback
        end
      end
    end
  end

  describe "#summary" do
    before(:each) do
      #TODO: why is this needed?
      JobSummary.delete_all

      @empty_summary = {
        :num_jobs => 0,
        :successful => 0,
        :cpu_time => 0,
        :memory_time => 0,
      }
    end

    it "produces correct summaries" do
      1.upto(3) do |num_days|
        [0, -2.hours, 2.hours, 3.minutes].each do |offset_begin|
          [0, -2.hours, 2.hours, 3.minutes].each do |offset_end|
            [true, false].each do |exclude_end|
              time_range = Range.new(base_time + offset_begin, base_time + num_days.days + offset_end, exclude_end)
              sum1 = JobSummary.summary(:range => time_range)
              sum2 = Job.summary(time_range)
              expect(sum1).to eql(sum2)
            end
          end
        end
      end
      expect(JobSummary.summary(:range => Time.new ... Time.new)).to eql(@empty_summary)
    end

    it "distinguishes between inclusive and exclusive ranges" do
      Summary = JobSummary
      sum = Summary.summary(:range => (base_time ... base_time + 1.days + 2.hours))
      expect(sum[:num_jobs]).to eql 26
      expect(sum[:successful]).to eql 13
      sum = Summary.summary(:range => (base_time .. base_time + 1.days + 2.hours))
      expect(sum[:num_jobs]).to eql 27
      expect(sum[:successful]).to eql 14
    end

    def check_time_bounds
      expect(JobSummary.summary).to eql(Job.summary)
      expect(JobSummary.minimum(:date)).to eql(base_time.to_date)
      expect(JobSummary.maximum(:date)).to eql(Time.now.utc.to_date - 1)
    end

    it "correctly finds the default time bounds" do
      Time.expects(:now).at_least(0).returns(base_time + 2.days)
      job = Job.order('end_time DESC').first
      job.end_time = Time.now
      job.save!
      check_time_bounds
      JobSummary.delete_all

      #Check the case where all systems are decommissioned.
      #TODO: split into a context?
      JobSummary.transaction(:requires_new => true) do
        System.active.each do |sys|
          sys.end_time = base_time + 2.days
          sys.save!
        end
        check_time_bounds
        raise ActiveRecord::Rollback
      end

      #Check the case where there are no jobs.
      #TODO: split into a context?
      Job.delete_all
      sum = JobSummary.summary
      expect(sum).to eql(@empty_summary)
      expect(JobSummary.any?).to eql false
    end

    it "correctly handles filtered summaries" do
      filters = {
        :user_name => 'test',
        :group_name => 'admin',
        :command_name => 'vi',
      }
      filters.each do |filter, value|
        filter_sym = "by_#{filter}".intern
        jobs = Job.send(filter_sym, value)
        sum1 = JobSummary.send(filter_sym, value).summary(:jobs => jobs)
        sum2 = jobs.summary
        expect(sum1).to eql(sum2)
      end
    end

    it "correctly handles inverted ranges" do
      t = base_time
      expect(JobSummary.summary(:range => t .. t - 1)).to eql(@empty_summary)
    end

    it "caches summaries" do
      JobSummary.expects(:summarize)
      range = base_time ... base_time + 1.days
      JobSummary.summary(:range => range)
    end

    it "uses the cached summaries" do
      JobSummary.summary
      Job.expects(:summary).never
      range = base_time ... base_time + 1.days
      JobSummary.summary(:range => range)
    end
  end

  it "validates fields" do
    fields = {
      :user => User.first,
      :system => System.first,
      :command_name => '',
      :date => Date.new(2012),
      :cpu_time => 100,
      :memory_time => 1000000,
    }

    sum = JobSummary.new(fields)
    expect(sum.valid?).to eql true

    fields.each_key do |field|
      job = JobSummary.new(fields)
      job.method("#{field}=".intern).call(nil)
      expect(job.valid?).to eql false
    end

    [:cpu_time, :memory_time].each do |field|
      job = JobSummary.new(fields)
      method = job.method("#{field}=".intern)
      method.call(-1)
      expect(job.valid?).to eql false
      method.call(0)
      expect(job.valid?).to eql true
    end
  end
end

