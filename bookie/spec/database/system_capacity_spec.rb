require 'spec_helper'

include Bookie::Database

describe Bookie::Database::SystemCapacity do
  #TODO: create a common example.
  describe "#by_time_range" do
    #TODO: handle infinities.
    context "with inclusive time ranges" do
      it "correctly filters by time range" do
        range_counts = {
          (base_time .. base_time + 20.hours) => 4,
          (base_time + 1 .. base_time + 20.hours) => 4,
          (base_time + 21.hours .. base_time + 30.hours) => 3,
          (base_time .. base_time) => 1
        }
        range_counts.each_pair do |range, count|
          expect(SystemCapacity.by_time_range(range).count).to eql count
        end
      end
    end

    context "with exclusive time ranges" do
      it "correctly filters by time range" do
        range_counts = {
          (base_time ... base_time + 20.hours + 1) => 4,
          (base_time + 1 ... base_time + 20.hours) => 2,
          (base_time + 21.hours ... base_time + 30.hours) => 3,
          (base_time ... base_time) => 0,
        }
        range_counts.each_pair do |range, count|
          expect(SystemCapacity.by_time_range(range).count).to eql count
        end
      end
    end

    #TODO: split inclusive/exclusive range tests

    it "correctly handles empty/inverted ranges" do
      (-1 .. 0).each do |offset|
        systems = SystemCapacity.by_time_range(base_time ... base_time + offset)
        expect(systems.count).to eql 0
      end
    end
  end

  describe "#summary" do
    before(:each) do
      #Take note of this; the calculations for the expected values in these
      #tests are based on this value of Time.now.
      #TODO: fix this hackiness?
      Time.expects(:now).returns(base_time + 30.hours).at_least_once
    end

    let(:summary) { create_summaries(SystemCapacity, base_time) }
    let(:summary_wide) { SystemCapacity.summary(base_time - 1.hours ... Time.now + 1.hours) }

    #All systems should have the same amount of memory.
    let(:memory_per_system) { SystemCapacity.first.memory }
    let(:cores_per_system) { SystemCapacity.first.cores }
    #The first system was up for 10 hours, down for 10, and up for another 10. The others were not decommissioned.
    #TODO: calculate from the database?
    let(:total_wall_time) { (10 + 10 + 30).hours }
    let(:total_memory_time) { total_wall_time * memory_per_system }

    context "when systems are active" do
      it "produces correct summaries" do
        expect(summary[:all]).to eql({
          :num_systems => 3,
          :avail_cpu_time => total_wall_time * cores_per_system,
          :avail_memory_time => total_wall_time * memory_per_system,
          :avail_memory_avg => Float(total_memory_time) / 30.hours,
        })

        expect(summary[:all_constrained]).to eql(summary[:all])

        #The clipped summary cuts 5 hours off each side.
        clipped_wall_time = (5 + 10 + 15).hours
        expect(summary[:clipped]).to eql({
          :num_systems => 3,
          :avail_cpu_time => clipped_wall_time * cores_per_system,
          :avail_memory_time => clipped_wall_time * memory_per_system,
          :avail_memory_avg => Float(clipped_wall_time * memory_per_system) / (20.hours),
        })

        #One extra hour of wall time for each active system
        wide_wall_time = total_wall_time + 3.hours
        expect(summary_wide).to eql({
          :num_systems => 3,
          :avail_cpu_time => wide_wall_time * cores_per_system,
          :avail_memory_time => memory_per_system * wide_wall_time,
          :avail_memory_avg => Float(wide_wall_time * memory_per_system) / 32.hours,
        })

        expect(summary[:empty]).to eql({
          :num_systems => 0,
          :avail_cpu_time => 0,
          :avail_memory_time => 0,
          :avail_memory_avg => 0.0,
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

        s1 = SystemCapacity.summary()
        expect(s1).to eql summary[:all]

        s1 = SystemCapacity.summary(base_time ... Time.now + 1.hour)
        s2 = summary[:all].dup
        s2[:avail_memory_avg] = Float(total_memory_time) / 31.hours
        expect(s1).to eql s2
      end
    end

    it "correctly handles inverted ranges" do
      t = base_time
      expect(SystemCapacity.summary(t ... t - 1)).to eql summary[:empty]
      expect(SystemCapacity.summary(t .. t - 1)).to eql summary[:empty]
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