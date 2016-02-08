require 'spec_helper'

module Helpers
  #Used for the "chooses the correct systems" examples
  #TODO: just use DummySender?
  def redefine_each_job(sender)
    def sender.each_job(filename)
      [0, 1001].each do |offset|
        job = JobStub.new
        job.user_name = 'blm'
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
  attr_accessor :user_id, :user_name
  attr_accessor :command_name
  attr_accessor :start_time, :wall_time
  attr_accessor :cpu_time, :memory
  attr_accessor :exit_code

  include Bookie::ModelHelpers

  def self.from_job(job)
    stub = self.new
    stub.user_id = job.user.id
    stub.user_name = job.user.name
    stub.command_name = job.command_name
    stub.start_time = job.start_time
    stub.wall_time = job.wall_time
    stub.cpu_time = job.cpu_time
    stub.memory = job.memory
    stub.exit_code = job.exit_code
    stub
  end

  def self.from_hash(hash)
    stub = self.new
    hash.each_pair do |key, value|
      stub.send("#{key}=", value)
    end
    stub
  end
end

describe Bookie::Sender do
  before(:all) do
    fields = {
      :name => test_config.hostname,
      #TODO: just pull the value from the config?
      #That way, we can eliminate the need to (re)define the system_type method.
      :system_type => new_dummy_sender(test_config).system_type,
      :cores => test_config.cores,
      :memory => test_config.memory,
    }
    #TODO: replace with let()?
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

  #This implicitly tests the ability to load the correct sender plugin.
  let(:sender) { new_dummy_sender(test_config) }

  before(:each) do
    Bookie::Database::Job.delete_all
  end

  it "correctly filters jobs" do
    job = JobStub.new
    job.user_name = "root"
    expect(sender.filtered?(job)).to eql true
    job.user_name = "test"
    expect(sender.filtered?(job)).to eql false
  end

  it "correctly sends jobs" do
    config = test_config.clone
    config.excluded_users = Set.new
    sender.send_data('dummy')
    jobs = Job.includes(:system)
    jobs.each do |job|
      expect(job.system.name).to eql config.hostname
    end
    expect(jobs.length).to eql 100
  end

  it "refuses to send jobs when jobs already have been sent from a file" do
    sender.send_data('dummy')
    expect {
      sender.send_data('dummy')
    }.to raise_error("Jobs already exist in the database for 'dummy'.")
  end

  it "correctly handles empty files" do
    Bookie::Database::Job.any_instance.expects(:'save!').never
    ActiveRecord::Relation.any_instance.expects(:'delete_all').never
    sender.send_data('/dev/null')
  end

  it "chooses the correct systems" do
    sender = new_dummy_sender(test_config)

    redefine_each_job(sender)

    sender.send_data('dummy')

    jobs = Bookie::Database::Job.by_system_name(test_config.hostname).order(:end_time).to_a
    expect(jobs[0].system).to eql @sys_1
    expect(jobs[1].system).to eql @sys_2
  end

  it "correctly finds duplicates" do
    sender.send_data('snapshot/torque')
    job = Bookie::Database::Job.first
    stub = JobStub.from_job(job)
    #The job's system should be @sys_2.
    #Just to make sure this test doesn't break later, I'll check it.
    #TODO: restore?
    #expect(expect(job.system).to eql @sys_2
    #expect(sender.duplicate(stub, @sys_1)).to eql nil
    expect(sender.duplicate(stub, job.system)).to eql job
    [:user_name, :command_name, :start_time, :wall_time, :cpu_time, :memory, :exit_code].each do |field|
      old_val = stub.send(field)
      if old_val.is_a?(String)
        stub.send("#{field}=", 'string')
      else
        stub.send("#{field}=", old_val + 1)
      end
      expect(sender.duplicate(stub, @sys_2)).to eql nil
      stub.send("#{field}=", old_val)
    end
  end

  it "deletes cached summaries that overlap the new jobs" do
    sender.send_data('dummy')
    time_min = Bookie::Database::Job.order(:start_time).first.start_time
    time_max = Bookie::Database::Job.order('end_time DESC').first.end_time
    Bookie::Database::Job.delete_all
    sender.expects(:clear_summaries).with(time_min.to_date, time_max.to_date)
    sender.send_data('dummy')
  end

  describe "#clear_summaries" do
    it "deletes cached summaries" do
      sender = new_dummy_sender(test_config)
      sender.send_data('dummy')

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
            :cpu_time => 1,
            :memory_time => 100
          )
        end
      end

      sender.send(:clear_summaries, date_start + 1, date_end - 1)

      sums = Bookie::Database::JobSummary.all.to_a
      expect(sums.length).to eql 9
      sums.each do |sum|
        #Since there are no jobs for @sys_dummy, its summaries should be left intact.
        unless sum.system == @sys_dummy
          expect((date_start + 1 .. date_end - 1).cover?(sum.date)).to eql false
        end
      end
      sums = Bookie::Database::JobSummary.by_date(Date.new(2012))
      expect(sums.count).to eql 1
      expect(sums.first.system).to eql @sys_dummy
    end
  end

  describe "#undo_send" do
    it "removes the correct entries" do
      sender.send_data('dummy')
      sender.send_data('snapshot/torque')
      sender.undo_send('dummy')

      expect(Bookie::Database::Job.count).to eql 1
      job = Bookie::Database::Job.first
      Bookie::Database::Job.delete_all
      sender.send_data('snapshot/torque')
      job2 = Bookie::Database::Job.first
      job2.id = job.id
      expect(job2).to eql job
    end

    it "switches systems if needed" do
      sender = new_dummy_sender(test_config)

      #TODO: don't do this!
      redefine_each_job(sender)

      sender.send_data('dummy')

      def sender.duplicate(job, system)
        #The returned object needs a #delete method.
        job.expects(:delete)
        job
      end

      Bookie::Database::System.expects(:find_current).returns(@sys_1).twice

      sender.undo_send('dummy')
    end

    it "deletes cached summaries in the affected range" do
      sender.send_data('dummy')
      time_min = Bookie::Database::Job.order(:start_time).first.start_time
      time_max = Bookie::Database::Job.order('end_time DESC').first.end_time
      sender.expects(:clear_summaries).with(time_min.to_date, time_max.to_date)
      sender.undo_send('dummy')
    end
  end
end

describe Bookie::ModelHelpers do
  let(:job) do
    job = JobStub.new
    job.user_name = "root"
    job.command_name =  "vi"
    job.start_time = Time.new
    job.wall_time = 3
    job.cpu_time = 2
    job.memory = 300
    job
  end

  it "correctly converts jobs to records" do
    Bookie::Database::Job.stubs(:new).returns(JobStub.new)
    record = job.to_record
    [:command_name, :start_time, :end_time, :wall_time, :cpu_time, :memory, :exit_code].each do |field|
      expect(record.send(field)).to eql job.send(field)
    end
  end

  it "correctly calculates end time" do
    expect(job.end_time).to eql job.start_time + job.wall_time
  end
end

