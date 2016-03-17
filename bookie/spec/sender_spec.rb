require 'spec_helper'
require 'sender_helper'

include SenderHelpers

#TODO: just set up a clean database environment for this test? (The main testing DB is ignored anyway.)
describe Bookie::Sender do
  before(:all) do
    Bookie::Database::Job.delete_all
  end

  let(:sender_config) { Bookie::SenderConfig.load(File.open('snapshot/sender_config.rb')) }

  let(:sys_1) do
    #TODO: just pull the system_type value from the config?
    #That way, we can eliminate the need to (re)define the system_type method.
    sys_1 = Bookie::Database::System.create!(
      name: sender_config.hostname,
      system_type: new_dummy_sender(sender_config).system_type,
    )

    cap_1 = Bookie::Database::SystemCapacity.create!(
      system: sys_1,
      start_time: base_time,
      end_time: base_time + 1000,
      cores: sender_config.cores,
      memory: sender_config.memory
    )
    cap_2 = cap_1.dup
    cap_2.start_time = base_time + 1001
    cap_2.end_time = nil
    cap_2.save!

    sys_1
  end

  let(:sys_dummy) do
    #TODO: create a system with no capacity entries?
    sys_dummy = sys_1.dup
    sys_dummy.name = 'dummy'
    sys_dummy.save!
    cap = sys_1.system_capacities.order('start_time ASC').first.dup
    cap.system = sys_dummy
    cap.start_time = base_time
    cap.save!
    sys_dummy
  end

  #This implicitly tests the ability to load the correct sender plugin.
  let(:sender) do
    #A quick hack to ensure that the systems exist by the time the sender needs them
    #This works because RSpec's 'let' uses lazy evaluation.
    sys_1
    sys_dummy

    new_dummy_sender(sender_config)
  end

  describe "#filtered?" do
    it "correctly filters jobs" do
      job = JobStub.new
      job.user_name = "root"
      expect(sender.filtered?(job)).to eql true
      job.user_name = "test"
      expect(sender.filtered?(job)).to eql false
    end
  end

  describe "#send" do
    #TODO: check for the #filtered? check?
    it "correctly sends jobs" do
      config = sender_config.clone
      config.job_filter = nil
      sender.send_data('dummy')
      jobs = Job.includes(:system)
      jobs.each do |job|
        expect(job.system.name).to eql config.hostname
      end
      expect(jobs.length).to eql DummySender::NUM_JOBS
    end

    it "refuses to send jobs when jobs already have been sent from a file" do
      sender.send_data('dummy')
      expect {
        sender.send_data('dummy')
      }.to raise_error("Jobs already exist in the database for 'dummy'.")
    end

    it "correctly handles empty files" do
      empty_sender = new_dummy_sender(sender_config, EmptyDummySender)
      Bookie::Database::Job.any_instance.expects(:'save!').never
      ActiveRecord::Relation.any_instance.expects(:'delete_all').never
      empty_sender.send_data('dummy')
    end
  end

  describe "#duplicate" do
    #TODO: split up?
    it "correctly finds duplicates" do
      sender.send_data('dummy')
      job = Bookie::Database::Job.first
      stub = JobStub.from_job(job)
      expect(sender.duplicate(stub)).to eql job

      stub_changed = stub.dup
      stub_changed.command_name = 'string'
      expect(sender.duplicate(stub_changed)).to eql nil

      [:user_id, :start_time, :wall_time, :cpu_time, :memory, :exit_code].each do |field|
        stub_changed = stub.dup
        stub_changed.send("#{field}=", stub.send(field) + 1)
        expect(sender.duplicate(stub_changed)).to eql nil
      end

      #A sender for another system won't detect a duplicate for this one.
      sender.stubs(:system).returns(Bookie::Database::System.find(2))
      expect(sender.duplicate(stub)).to eql nil
    end
  end

  it "deletes cached summaries that overlap the new jobs" do
    sender.send_data('dummy')
    date_min = Bookie::Database::Job.minimum(:start_time).to_date
    date_max = Bookie::Database::Job.maximum(:end_time).to_date

    Bookie::Database::Job.delete_all
    sender.expects(:clear_summaries).with(date_min, date_max)
    sender.send_data('dummy')
  end

  describe "#clear_summaries" do
    it "deletes cached summaries" do
      sender.send_data('dummy')

      user = Bookie::Database::User.first
      date_start = base_time.to_date - 2
      date_end = date_start + 4
      (date_start .. date_end).each do |date|
        [sys_1, sys_dummy].each do |system|
          Bookie::Database::JobSummary.create!(
            date: date, system: system,
            user: user, command_name: 'vi',
            cpu_time: 1, memory_time: 100
          )
        end
      end

      sender.send(:clear_summaries, date_start + 1, date_end - 1)

      sums = Bookie::Database::JobSummary.all.to_a
      expect(sums.length).to eql 7
      sums.each do |sum|
        #Since there are no jobs for sys_dummy, its summaries should be left intact.
        unless sum.system == sys_dummy
          expect((date_start + 1 .. date_end - 1).cover?(sum.date)).to eql false
        end
      end
      sums = Bookie::Database::JobSummary.where(date: Date.new(2012))
      expect(sums.count).to eql 1
      expect(sums.first.system).to eql sys_dummy
    end
  end

  describe "#undo_send" do
    it "removes the correct entries" do
      sender_short = new_dummy_sender(sender_config, ShortDummySender)
      sender.send_data('dummy')
      sender_short.send_data('dummy2')
      sender.undo_send('dummy')

      expect(Bookie::Database::Job.count).to eql 1
      job = Bookie::Database::Job.first
      Bookie::Database::Job.delete_all
      sender.send_data('dummy')
      job2 = Bookie::Database::Job.first
      job2.id = job.id
      expect(job2).to eql job
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

  it "creates users when necessary"

  it "correctly calculates end time" do
    expect(job.end_time).to eql job.start_time + job.wall_time
  end
end

