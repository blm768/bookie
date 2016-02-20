require 'spec_helper'
require 'database/summary_helper'

include Bookie::Database

include SummaryHelpers

RSpec::Matchers.define :be_job_within_time_range do |time_range|
  match do |job|
    expect(time_range).to cover(job.start_time)
    #This check is required because of a peculiarity of #within_time_range;
    #jobs with an end_time one second beyond the last value in the range
    #are still included (intentionally).
    range_extended = Range.new(time_range.begin, time_range.end + 1, time_range.exclude_end?)
    expect(range_extended).to cover(job.end_time)
  end
end

describe Bookie::Database::Job do
  describe "#end_time" do
    it "correctly calculates end time" do
      Job.find_each do |job|
        expect(job.end_time).to eql job.start_time + job.wall_time
      end
    end

    it "updates the model attribute" do
      job = Job.first
      job.wall_time -= 1
      job.save!
      expect(job.read_attribute(:end_time)).to eql job.start_time + job.wall_time
    end
  end

  describe "#by_time_range" do
    let(:base_start) { base_time + 1.hours }
    let(:base_end) { base_start + 2.hours }

    it "filters by inclusive time range" do
      jobs = Job.by_time_range(base_start ... base_end + 1)
      expect(jobs.count).to eql 3
      jobs = Job.by_time_range(base_start + 1 ... base_end)
      expect(jobs.count).to eql 2
      jobs = Job.by_time_range(base_start ... base_start)
      expect(jobs.length).to eql 0
    end

    it "filters by exclusive time range" do
      jobs = Job.by_time_range(base_start + 1 .. base_end)
      expect(jobs.count).to eql 3
      jobs = Job.by_time_range(base_start .. base_end - 1)
      expect(jobs.count).to eql 2
      jobs = Job.by_time_range(base_start .. base_start)
      expect(jobs.count).to eql 1
    end

    context "with an empty range" do
      it "finds no jobs" do
        (-1 .. 0).each do |offset|
          jobs = Job.by_time_range(base_start ... base_start + offset)
          expect(jobs.count).to eql 0
        end
      end
    end
  end

  describe "#within_time_range" do
    let(:base_start) { base_time + 1.hours + 1 }
    let(:base_end) { base_time + 5.hours - 1 }

    it "finds jobs within the range" do
      [true, false].each do |exclude_end|
        time_range = Range.new(base_start, base_end, exclude_end)
        jobs = Job.within_time_range(time_range)
        expect(jobs.count).to eql (exclude_end ? 2 : 3)
        jobs.each do |job|
          expect(job).to be_job_within_time_range(time_range)
        end
      end
    end

    context "with an empty range" do
      it "finds no jobs" do
        jobs = Job.within_time_range(base_start ... base_start)
        expect(jobs.count).to eql(0)
      end
    end
  end

  describe "#summary" do
    let(:count) { Job.count }
    let(:summary) { create_summaries(Job, base_time) }

    #TODO: test the case where a job extends on both sides of the summary range?
    it "produces correct summary totals" do
      expect(summary[:all]).to eql({
        :num_jobs => count,
        :successful => 20,
        :cpu_time => count * 100,
        :memory_time => count * 200 * 1.hour,
      })

      expect(summary[:all_constrained]).to eql(summary[:all])
      expect(summary[:wide]).to eql(summary[:all])

      expect(summary[:all_filtered]).to eql({
        :num_jobs => count / 2,
        :successful => 20,
        :cpu_time => count * 100 / 2,
        :memory_time => count * 100 * 1.hour,
      })

      num_clipped_jobs = summary[:clipped][:num_jobs]
      expect(summary[:clipped]).to eql({
        :num_jobs => 25,
        :cpu_time => num_clipped_jobs * 100 - 50,
        #TODO: this seems off. Why?
        :memory_time => num_clipped_jobs * 200 * 3600 - 100 * 3600,
        :successful => num_clipped_jobs / 2 + 1,
      })
    end

    it "correctly handles summaries of empty sets" do
      expect(summary[:empty]).to eql({
          :num_jobs => 0,
          :cpu_time => 0,
          :memory_time => 0,
          :successful => 0,
        })
    end

    it "correctly handles inverted ranges" do
      expect(Job.summary(Time.now() ... Time.now() - 1)).to eql summary[:empty]
      expect(Job.summary(Time.now() .. Time.now() - 1)).to eql summary[:empty]
    end

    it "distinguishes between inclusive and exclusive ranges" do
      sum = Job.summary(base_time ... base_time + 3600)
      expect(sum[:num_jobs]).to eql 1
      sum = Job.summary(base_time .. base_time + 3600)
      expect(sum[:num_jobs]).to eql 2
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
    expect(job.valid?).to eql true

    fields.each_key do |field|
      job = Job.new(fields)
      job.method("#{field}=".intern).call(nil)
      expect(job.valid?).to eql false
    end

    [:cpu_time, :wall_time, :memory].each do |field|
      job = Job.new(fields)
      m = job.method("#{field}=".intern)
      m.call(-1)
      expect(job.valid?).to eql false
      m.call(0)
      expect(job.valid?).to eql true
    end
  end
end
