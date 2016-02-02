require 'spec_helper'

include Bookie::Database

describe Bookie::Database::System do
  describe "#active" do
    it { expect(System.active.length).to eql 3 }
  end

  it "correctly filters by name" do
    expect(System.by_name('test1').length).to eql 2
    expect(System.by_name('test2').length).to eql 1
    expect(System.by_name('test3').length).to eql 1
  end

  it "correctly filters by system type" do
    ['Standalone', 'TORQUE cluster'].each do |type|
      t = SystemType.find_by_name(type)
      expect(System.by_system_type(t).length).to eql 2
    end
  end

  #TODO: create a common example.
  describe "#by_time_range" do
    it "correctly filters by time range" do
      systems = System.by_time_range(base_time ... base_time + 36000 * 2 + 1)
      expect(systems.count).to eql 3
      systems = System.by_time_range(base_time + 1 ... base_time + 36000 * 2)
      expect(systems.count).to eql 2
      systems = System.by_time_range(base_time ... base_time)
      expect(systems.length).to eql 0
      systems = System.by_time_range(base_time .. base_time + 36000 * 2)
      expect(systems.count).to eql 3
      systems = System.by_time_range(base_time .. base_time)
      expect(systems.count).to eql 1
    end

    #TODO: split inclusive/exclusive range tests

    it "correctly handles empty/inverted ranges" do
      (-1 .. 0).each do |offset|
        systems = System.by_time_range(base_time ... base_time + offset)
        expect(systems.count).to eql 0
      end
    end
  end

  describe "#summary" do
    before(:each) do
      #Take note of this; the calculations for the expected values in these
      #tests are based on this value of Time.now.
      Time.expects(:now).returns(base_time + 40.hours).at_least_once
    end

    let(:summary) { create_summaries(System, base_time) }
    let(:summary_wide) { System.summary(base_time - 1.hours ... Time.now + 1.hours) }

    #All systems should have the same amount of memory.
    let(:memory_per_system) { System.first.memory }
    let(:cores_per_system) { System.first.cores }
    #The first system was only up for 10 hours; the others were not decommissioned.
    let(:total_wall_time) { (10 + 30 + 20 + 10).hours }
    let(:total_memory_time) { total_wall_time * memory_per_system }

    context "when some systems are active" do
      it "produces correct summaries" do
        expect(summary[:all]).to eql({
          :num_systems => 4,
          :avail_cpu_time => total_wall_time * cores_per_system,
          :avail_memory_time => total_wall_time * memory_per_system,
          :avail_memory_avg => Float(total_memory_time) / 40.hours,
        })

        expect(summary[:all_constrained]).to eql(summary[:all])

        clipped_wall_time = (10 + 15 + 5).hours - 30.minutes
        expect(summary[:clipped]).to eql({
          :num_systems => 3,
          :avail_cpu_time => clipped_wall_time * cores_per_system,
          :avail_memory_time => clipped_wall_time * memory_per_system,
          :avail_memory_avg => Float(clipped_wall_time * memory_per_system) / (25.hours - 30.minutes),
        })

        #One extra hour of wall time for each active system
        wide_wall_time = total_wall_time + 3.hours
        expect(summary_wide).to eql({
          :num_systems => 4,
          :avail_cpu_time => wide_wall_time * cores_per_system,
          :avail_memory_time => memory_per_system * wide_wall_time,
          :avail_memory_avg => Float(wide_wall_time * memory_per_system) / 42.hours,
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
        System.find_each do |system|
          unless system.end_time
            #Only works because of the mock in the before(:all) block
            system.end_time = Time.now
            system.save!
          end
        end

        s1 = System.summary()
        expect(s1).to eql summary[:all]

        s1 = System.summary(base_time ... Time.now + 1.hour)
        s2 = summary[:all].dup
        s2[:avail_memory_avg] = Float(total_memory_time) / 41.hours
        expect(s1).to eql s2
      end
    end

    it "correctly handles inverted ranges" do
      t = base_time
      expect(System.summary(t ... t - 1)).to eql summary[:empty]
      expect(System.summary(t .. t - 1)).to eql summary[:empty]
    end
  end

  describe "#find_current" do
    before(:all) do
      @config_t1 = test_config.clone

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
      expect(System.find_current(@sender_2).id).to eql 2
      expect(System.find_current(@sender_2, Time.now).id).to eql 2
      expect(System.find_current(@sender_1, base_time).id).to eql 1
    end

    it "correctly detects the lack of a matching system" do
      expect {
        System.find_current(@sender_1, base_time - 1.years)
      }.to raise_error(/^There is no system with hostname 'test1' that was recorded as active at /)
      @config_t1.expects(:hostname).at_least_once.returns('test1000')
      expect {
        System.find_current(@sender_1, base_time)
      }.to raise_error(/^There is no system with hostname 'test1000' that was recorded as active at /)
    end

    it "correctly detects conflicts" do
      config = test_config.clone
      config.hostname = 'test1'
      config.cores = 2
      config.memory = 1000000

      sender = Bookie::Sender.new(config)
      [:cores, :memory].each do |field|
        config.expects(field).at_least_once.returns("value")
        expect {
          System.find_current(sender)
        }.to raise_error(System::SystemConflictError)
        config.unstub(field)
      end
      sender.expects(:system_type).returns(SystemType.find_by_name("Standalone"))
      expect {
        System.find_current(sender)
      }.to raise_error(System::SystemConflictError)
    end
  end

  it "correctly decommissions" do
    sys = System.active.find_by_name('test1')
    begin
      sys.decommission(sys.start_time + 3)
      expect(sys.end_time).to eql sys.start_time + 3
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
      :system_type => SystemType.first,
      :start_time => base_time
    }

    expect(System.new(fields).valid?).to eql true

    fields.each_key do |field|
      system = System.new(fields)
      system.method("#{field}=".intern).call(nil)
      expect(system.valid?).to eql false
    end

    system = System.new(fields)
    system.name = ''
    expect(system.valid?).to eql false

    [:cores, :memory].each do |field|
      system = System.new(fields)
      m = system.method("#{field}=".intern)
      m.call(-1)
      expect(system.valid?).to eql false
      m.call(0)
      expect(system.valid?).to eql true
    end

    system = System.new(fields)
    system.end_time = base_time
    expect(system.valid?).to eql true
    system.end_time += 5
    expect(system.valid?).to eql true
    system.end_time -= 10
    expect(system.valid?).to eql false
  end
end
