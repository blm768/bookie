require 'spec_helper'

include Bookie::Database

RSpec::Matchers.define :have_unique_system_associations do
  match do |systems|
    method_object_id = Object.instance_method(:object_id)
    #Maps associations to object_ids
    association_ids = {}
    systems.each do |system|
      sys_type = system.system_type
      sys_type_id = method_object_id.bind(sys_type).call
      if association_ids.include?(sys_type)
        return false unless association_ids[sys_type] == sys_type_id
      else
        association_ids[sys_type] = sys_type_id
      end
    end

    true
  end
end

describe Bookie::Database::System do
  describe "#active" do
    it { System.active.length.should eql 3 }
  end
  
  it "correctly filters by name" do
    System.by_name('test1').length.should eql 2
    System.by_name('test2').length.should eql 1
    System.by_name('test3').length.should eql 1
  end
  
  it "correctly filters by system type" do
    ['Standalone', 'TORQUE cluster'].each do |type|
      t = SystemType.find_by_name(type)
      System.by_system_type(t).length.should eql 2
    end
  end

  describe "#all_with_associations" do
    it { expect(System.limit(5).all_with_associations).to have_unique_system_associations }
  end

  #TODO: rename this method and create a common example.
  describe "#by_time_range" do
    it "correctly filters by time range" do
      systems = System.by_time_range(base_time ... base_time + 36000 * 2 + 1)
      systems.count.should eql 3
      systems = System.by_time_range(base_time + 1 ... base_time + 36000 * 2)
      systems.count.should eql 2
      systems = System.by_time_range(base_time ... base_time)
      systems.length.should eql 0
      systems = System.by_time_range(base_time .. base_time + 36000 * 2)
      systems.count.should eql 3
      systems = System.by_time_range(base_time .. base_time)
      systems.count.should eql 1
    end

    #TODO: split inclusive/exclusive range tests
    
    it "correctly handles empty/inverted ranges" do
      (-1 .. 0).each do |offset|
        systems = System.by_time_range(base_time ... base_time + offset)
        systems.count.should eql 0
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
    
    #The first system was only up for 10 hours; the others were not decommissioned.
    let(:total_wall_time) { (10 + 30 + 20 + 10).hours }
    #All systems should have the same amount of memory.
    let(:memory_per_system) { System.first.memory }

    #TODO: figure out why this randomly fails.
    context "when some systems are active" do
      it "produces correct summaries" do
        total_cpu_time = total_wall_time * 2
        avg_mem = Float(memory_per_system * total_wall_time / 40.hours)
        expect(summary[:all]).to eql({
          :num_systems => 4,
          :avail_cpu_time => total_cpu_time,
          :avail_memory_time => 1000000 * total_wall_time,
          :avail_memory_avg => avg_mem,
        })

        expect(summary[:all_constrained]).to eql(summary[:all])

        clipped_wall_time = (10 + 15 + 5).hours - 30.minutes
        clipped_cpu_time = clipped_wall_time * 2
        clipped_avg_mem = Float(memory_per_system * clipped_wall_time) / (25.hours - 30.minutes)
        expect(summary[:clipped]).to eql({
          :num_systems => 3,
          :avail_cpu_time => clipped_cpu_time,
          :avail_memory_time => memory_per_system * clipped_wall_time,
          :avail_memory_avg => clipped_avg_mem,
        })

        wide_wall_time = total_wall_time + 2.hours
        wide_cpu_time = wide_wall_time * 2
        wide_avg_mem = Float(memory_per_system * wide_wall_time) / 42.hours
        expect(summary_wide).to eql({
          :num_systems => 4,
          :avail_cpu_time => wide_cpu_time,
          :avail_memory_time => memory_per_system * wide_wall_time,
          :avail_memory_avg => wide_avg_mem,
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
        s1.should eql summary[:all]

        s1 = System.summary(base_time ... Time.now + 1.hour)
        s2 = summary[:all].dup
        s2[:avail_memory_avg] = Float(memory_per_system * total_wall_time) / 41.hours
        s1.should eql s2
      end
    end
    
    it "correctly handles inverted ranges" do
      t = base_time
      System.summary(t ... t - 1).should eql summary[:empty]
      System.summary(t .. t - 1).should eql summary[:empty]
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
      System.find_current(@sender_2).id.should eql 2
      System.find_current(@sender_2, Time.now).id.should eql 2
      System.find_current(@sender_1, base_time).id.should eql 1
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
      sys.end_time.should eql sys.start_time + 3
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
    
    System.new(fields).valid?.should eql true
    
    fields.each_key do |field|
      system = System.new(fields)
      system.method("#{field}=".intern).call(nil)
      system.valid?.should eql false
    end
    
    system = System.new(fields)
    system.name = ''
    system.valid?.should eql false
    
    [:cores, :memory].each do |field|
      system = System.new(fields)
      m = system.method("#{field}=".intern)
      m.call(-1)
      system.valid?.should eql false
      m.call(0)
      system.valid?.should eql true
    end
    
    system = System.new(fields)
    system.end_time = base_time
    system.valid?.should eql true
    system.end_time += 5
    system.valid?.should eql true
    system.end_time -= 10
    system.valid?.should eql false
  end
end

