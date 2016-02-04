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
        job.end_time = job.start_time + 1000
        job.cpu_time = 2
        job.memory = 300
        job.exit_code = 0
        yield job
      end
    end
  end
end

class JobStub
  attr_accessor :user_name, :group_name
  attr_accessor :command_name
  attr_accessor :start_time, :end_time
  attr_accessor :cpu_time, :memory
  attr_accessor :exit_code

  include Bookie::ModelHelpers

  def self.from_job(job)
    stub = self.new
    stub.user_name = job.user.name
    stub.group_name = job.user.group.name
    stub.command_name = job.command_name
    stub.start_time = job.start_time
    stub.end_time = job.end_time
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

  after(:all) do
    rollback_transaction
  end

  let(:sender) { Bookie::Sender.new(test_config) }
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
    sender.send_data('snapshot/torque_large')
    jobs = Job.includes(:system)
    jobs.each do |job|
      expect(job.system.name).to eql config.hostname
    end
    expect(jobs.length).to eql 100
  end

  it "refuses to send jobs when jobs already have been sent from a file" do
    sender.send_data('snapshot/torque_large')
    expect {
      sender.send_data('snapshot/torque_large')
    }.to raise_error("Jobs already exist in the database for 'snapshot/torque_large'.")
  end

  it "correctly handles empty files" do
    Bookie::Database::Job.any_instance.expects(:'save!').never
    ActiveRecord::Relation.any_instance.expects(:'delete_all').never
    sender.send_data('/dev/null')
  end

  it "handles missing files" do
    expect { sender.send_data('snapshot/abc') }.to raise_error("File 'snapshot/abc' does not exist.")
  end

  it "chooses the correct systems" do
    sender = Bookie::Sender.new(test_config)

    redefine_each_job(sender)

    #The filename is just a dummy argument.
    sender.send_data('snapshot/pacct')

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
    [:user_name, :group_name, :command_name, :start_time, :end_time, :cpu_time, :memory, :exit_code].each do |field|
      old_val = stub.send(field)
      #Switch up the field values:
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
    sender.send_data('snapshot/torque_large')
    time_min = Bookie::Database::Job.order(:start_time).first.start_time
    time_max = Bookie::Database::Job.order('end_time DESC').first.end_time
    Bookie::Database::Job.delete_all
    sender.expects(:clear_summaries).with(time_min.to_date, time_max.to_date)
    sender.send_data('snapshot/torque_large')
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
      sender.send_data('snapshot/torque_large')
      sender.send_data('snapshot/torque')
      sender.undo_send('snapshot/torque_large')

      expect(Bookie::Database::Job.count).to eql 1
      job = Bookie::Database::Job.first
      Bookie::Database::Job.delete_all
      sender.send_data('snapshot/torque')
      job2 = Bookie::Database::Job.first
      job2.id = job.id
      expect(job2).to eql job
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

      Bookie::Database::System.expects(:find_current).returns(@sys_1).twice

      sender.undo_send('snapshot/pacct')
    end

    it "deletes cached summaries in the affected range" do
      sender.send_data('snapshot/torque_large')
      time_min = Bookie::Database::Job.order(:start_time).first.start_time
      time_max = Bookie::Database::Job.order('end_time DESC').first.end_time
      sender.expects(:clear_summaries).with(time_min.to_date, time_max.to_date)
      sender.undo_send('snapshot/torque_large')
    end
  end
end

describe Bookie::ModelHelpers do
  before(:all) do
    @job = JobStub.new
    @job.command_name =  "vi"
    @job.start_time = Time.new
    @job.end_time = @job.start_time + 3
    @job.cpu_time = 2
    @job.memory = 300
    @job.exit_code = 0
  end

  it "correctly converts jobs to records" do
    Bookie::Database::Job.stubs(:new).returns(JobStub.new)
    djob = @job.to_record
    #TODO: grab this list from somewhere useful instead of hard-coding it?
    [:command_name, :start_time, :end_time, :cpu_time, :memory, :exit_code].each do |field|
      expect(djob.send(field)).to eql @job.send(field)
    end
  end
end
