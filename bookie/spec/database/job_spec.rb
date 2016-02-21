require 'spec_helper'
require 'database/summary_helper'

include Bookie::Database

include SummaryHelpers

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
    let(:base_start) { base_time + 1.hours + 1 }
    let(:base_end) { base_time + 5.hours - 1 }

    context "with a closed range" do
      it "filters by time range" do
        jobs = Job.by_time_range(base_start + 2.hours, base_end)
        expect(jobs.count).to eql 2
        jobs = Job.by_time_range(base_start + 1, base_end)
        expect(jobs.count).to eql 4
      end
    end

    context "with an empty range" do
      it "finds no jobs" do
        (-1 .. 0).each do |offset|
          jobs = Job.by_time_range(base_start, base_start + offset)
          expect(jobs.count).to eql 0
        end
      end
    end
  end

  describe "#within_time_range" do
    let(:base_start) { base_time + 1.hours + 1 }
    let(:base_end) { base_time + 5.hours - 1 }

    #TODO: add these contexts to other tests.
    context "with open ranges" do
      it "finds jobs within the range" do
        expect(Job.within_time_range(nil, nil).count).to eql Job.count
        expect(Job.within_time_range(base_start, nil).count).to eql Job.count - 2
        expect(Job.within_time_range(nil, base_end).count).to eql 4
      end
    end

    context "with a closed range" do
      it "finds jobs within the range" do
        jobs = Job.within_time_range(base_start, base_end)
        puts Job.within_time_range(base_time, base_time + 30.hours).to_sql
        expect(jobs.count).to eql 2
        jobs.each do |job|
          [job.start_time, job.end_time].each do |time|
            expect(base_start ... base_end).to cover(job.start_time)
          end
        end
      end
    end

    context "with an empty range" do
      it "finds no jobs" do
        jobs = Job.within_time_range(base_start, base_start)
        expect(jobs.count).to eql 0
      end
    end
  end

  describe "#summary" do
    let(:count) { Job.count }
    let(:summary) { create_summaries(Job, base_time) }
    let(:summary_filtered) { Job.where(command_name: 'vi').summary(base_time, base_time + 30.hours) }

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

      expect(summary_filtered).to eql({
        num_jobs: count / 2,
        successful: 20,
        cpu_time: count * 100 / 2,
        memory_time: count * 100 * 1.hour,
      })

      expect(summary[:clipped]).to eql({
        num_jobs: 40,
        cpu_time: 39 * 100,
        memory_time: 39 * 200 * 1.hour,
        successful: 40 / 2,
      })
    end

    it "correctly handles summaries of empty sets" do
      expect(summary[:empty]).to eql({
          num_jobs: 0,
          cpu_time: 0,
          memory_time: 0,
          successful: 0,
        })
    end

    context "with empty/inverted ranges" do
      it "returns an empty summary" do
        [0, -1].each do |offset|
          expect(Job.summary(base_time, base_time + offset)).to eql summary[:empty]
        end
      end
    end
  end

  it "validates fields" do
    fields = {
      user: User.first, system: System.first,
      command_name: '', exit_code: 0,
      cpu_time: 100, memory: 10000,
      start_time: base_time, wall_time: 1000
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
