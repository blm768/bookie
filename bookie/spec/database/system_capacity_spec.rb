require 'spec_helper'

include Bookie::Database

describe Bookie::Database::SystemCapacity do
  #TODO: create a common example.
  describe "#by_time_range" do
    #TODO: handle nils.

    it "correctly filters by time range" do
      range_counts = {
        (base_time ... base_time + 20.hours + 1) => 4,
        (base_time + 1 ... base_time + 20.hours) => 2,
        (base_time + 21.hours ... base_time + 30.hours) => 3,
        (base_time ... base_time) => 0,
      }
      range_counts.each_pair do |range, count|
        expect(SystemCapacity.by_time_range(range.first, range.last).count).to eql count
      end
    end


    context "with empty/inverted ranges" do
      it "returns an empty summary" do
        (-1 .. 0).each do |offset|
          systems = SystemCapacity.by_time_range(base_time, base_time + offset)
          expect(systems.count).to eql 0
        end
      end
    end
  end

  describe "#summary" do
    before(:each) do
      Time.stubs(:now).returns(SummaryHelpers::BASE_END + SummaryHelpers::WIDE_MARGIN)
    end

    let(:summary) { create_summaries(SystemCapacity) }

    #All systems should have the same amount of memory.
    let(:memory_per_system) { SystemCapacity.first.memory }
    let(:cores_per_system) { SystemCapacity.first.cores }
    #The first system was up for 10 hours, down for 10, and up again. The others were not decommissioned.
    let(:constrained_wall_time) { (10 + 10 + 30).hours }
    let(:wide_wall_time) { constrained_wall_time + 3 * SummaryHelpers::WIDE_MARGIN }
    let(:constrained_memory_time) { constrained_wall_time * memory_per_system }
    let(:wide_memory_time) { wide_wall_time * memory_per_system }


    context "when systems are active" do
      #TODO: split into contexts.
      it "produces correct summaries" do
        expect(summary[:all]).to eql({
          num_systems: 3,
          avail_cpu_time: wide_wall_time * cores_per_system,
          avail_memory_time: wide_wall_time * memory_per_system,
          avail_memory_avg: Float(wide_memory_time) / 31.hours,
        })

        #TODO: split into another example/context?
        expect(summary[:all_constrained]).to eql(
          num_systems: 3,
          avail_cpu_time: constrained_wall_time * cores_per_system,
          avail_memory_time: constrained_wall_time * memory_per_system,
          avail_memory_avg: Float(constrained_memory_time) / SummaryHelpers::BASE_INTERVAL
        )

        clipped_wall_time = constrained_wall_time - 4 * SummaryHelpers::CLIP_MARGIN
        expect(summary[:clipped]).to eql({
          num_systems: 3,
          avail_cpu_time: clipped_wall_time * cores_per_system,
          avail_memory_time: clipped_wall_time * memory_per_system,
          avail_memory_avg: Float(memory_per_system * clipped_wall_time) / SummaryHelpers::CLIPPED_TIME_INTERVAL
        })

        expect(summary[:wide]).to eql({
          num_systems: 3,
          avail_cpu_time: cores_per_system * wide_wall_time,
          avail_memory_time: memory_per_system * wide_wall_time,
          avail_memory_avg: Float(wide_wall_time * memory_per_system) / SummaryHelpers::WIDE_TIME_INTERVAL
        })

        expect(summary[:empty]).to eql({
          num_systems: 0,
          avail_cpu_time: 0,
          avail_memory_time: 0,
          avail_memory_avg: 0.0,
        })
      end
    end

    context "when no systems are active" do
      it "produces correct summaries" do
        SystemCapacity.where(end_time: nil).find_each do |cap|
          #Only works because of the mock in the before(:all) block
          cap.end_time = Time.now
          cap.save!
        end

        s1 = SystemCapacity.summary(nil, nil)
        expect(s1).to eql summary[:all]

        s1 = SystemCapacity.summary(base_time, Time.now + SummaryHelpers::WIDE_MARGIN)
        s2 = summary[:all].dup
        time_interval = SummaryHelpers::BASE_INTERVAL + SummaryHelpers::WIDE_MARGIN * 2
        s2[:avail_memory_avg] = Float(wide_memory_time) / time_interval
        expect(s1).to eql s2
      end
    end

    context "with empty/inverted ranges" do
      it "returns an empty summary" do
        [0, -1].each do |offset|
          expect(SystemCapacity.summary(base_time, base_time + offset)).to eql summary[:empty]
        end
      end
    end
  end

  it "validates fields" do
    fields = {
      system: System.first,
      cores: 2,
      memory: 1000000,
      start_time: base_time
    }

    expect(SystemCapacity.new(fields).valid?).to eql true

    fields.each_key do |field|
      cap = SystemCapacity.new(fields)
      cap.method("#{field}=".intern).call(nil)
      expect(cap.valid?).to eql false
    end

    [:cores, :memory].each do |field|
      cap = SystemCapacity.new(fields)
      m = cap.method("#{field}=")
      m.call(-1)
      expect(cap.valid?).to eql false
      m.call(0)
      expect(cap.valid?).to eql true
    end

    cap = SystemCapacity.new(fields)
    cap.end_time = base_time
    expect(cap.valid?).to eql true
    cap.end_time += 5
    expect(cap.valid?).to eql true
    cap.end_time -= 10
    expect(cap.valid?).to eql false
  end
end
