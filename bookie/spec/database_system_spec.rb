require 'spec_helper'

describe Bookie::Database::System do
  before(:each) do
    @systems = Bookie::Database::System
  end

  it "correctly finds active systems" do
    Bookie::Database::System.active_systems.length.should eql 3
  end
  
  it "correctly filters by name" do
    Bookie::Database::System.by_name('test1').length.should eql 2
    Bookie::Database::System.by_name('test2').length.should eql 1
    Bookie::Database::System.by_name('test3').length.should eql 1
  end
  
  it "correctly filters by system type" do
    ['Standalone', 'TORQUE cluster'].each do |type|
      t = Bookie::Database::SystemType.find_by_name(type)
      Bookie::Database::System.by_system_type(t).length.should eql 2
    end
  end

  describe "#all_with_relations" do
    it "loads all relations" do
      systems = Bookie::Database::System.limit(5).all_with_relations
      relation_ids = {}
      Bookie::Database::SystemType.expects(:new).never
      systems.each do |system|
        test_system_relation_identity(system, relation_ids)
      end
    end
  end

  describe "#by_time_range_inclusive" do
    it "correctly filters by inclusive time range" do
      systems = @systems.by_time_range_inclusive(base_time ... base_time + 36000 * 2 + 1)
      systems.count.should eql 3
      systems = @systems.by_time_range_inclusive(base_time + 1 ... base_time + 36000 * 2)
      systems.count.should eql 2
      systems = @systems.by_time_range_inclusive(base_time ... base_time)
      systems.length.should eql 0
      systems = @systems.by_time_range_inclusive(base_time .. base_time + 36000 * 2)
      systems.count.should eql 3
      systems = @systems.by_time_range_inclusive(base_time .. base_time)
      systems.count.should eql 1
    end
    
    it "correctly handles empty/inverted ranges" do
      (-1 .. 0).each do |offset|
        systems = @systems.by_time_range_inclusive(base_time ... base_time + offset)
        systems.count.should eql 0
      end
    end
  end

  describe "#summary" do
    before(:all) do
      Time.expects(:now).returns(base_time + 3600 * 40).at_least_once
      @systems = Bookie::Database::System
      @summary = create_summaries(@systems, base_time)
      @summary_wide = @systems.summary(base_time - 3600 ... base_time + 3600 * 41)
    end
    
    #TODO: figure out why this randomly fails.
    it "produces correct summaries" do
      system_total_wall_time = 3600 * (10 + 30 + 20 + 10)
      system_clipped_wall_time = 3600 * (10 + 15 + 5) - 1800
      system_wide_wall_time = system_total_wall_time + 3600 * 3
      system_total_cpu_time = system_total_wall_time * 2
      clipped_cpu_time = system_clipped_wall_time * 2
      system_wide_cpu_time = system_wide_wall_time * 2
      avg_mem = Float(1000000 * system_total_wall_time / (3600 * 40))
      clipped_avg_mem = Float(1000000 * system_clipped_wall_time) / (3600 * 25 - 1800)
      wide_avg_mem = Float(1000000 * system_wide_wall_time) / (3600 * 42)
      @summary[:all][:systems].length.should eql 4
      @summary[:all][:avail_cpu_time].should eql system_total_cpu_time
      @summary[:all][:avail_memory_time].should eql 1000000 * system_total_wall_time
      @summary[:all][:avail_memory_avg].should eql avg_mem
      expect(@summary[:all_constrained]).to eql(@summary[:all])
      @summary[:clipped][:systems].length.should eql 3
      @summary[:clipped][:avail_cpu_time].should eql clipped_cpu_time
      @summary[:clipped][:avail_memory_time].should eql system_clipped_wall_time * 1000000
      @summary[:clipped][:avail_memory_avg].should eql clipped_avg_mem
      @summary_wide[:systems].length.should eql 4
      @summary_wide[:avail_cpu_time].should eql system_wide_cpu_time
      @summary_wide[:avail_memory_time].should eql 1000000 * system_wide_wall_time
      @summary_wide[:avail_memory_avg].should eql wide_avg_mem
      @summary[:empty][:systems].length.should eql 0
      @summary[:empty][:avail_cpu_time].should eql 0
      @summary[:empty][:avail_memory_time].should eql 0
      @summary[:empty][:avail_memory_avg].should eql 0.0

      @systems.find_each do |system|
        unless system.end_time
          #Only works because of the mock in the before(:all) block
          system.end_time = Time.now
          system.save!
        end
      end
      summary_all_systems_ended = @systems.summary()
      summary_all_systems_ended.should eql @summary[:all]
      summary_all_systems_ended = @systems.summary(base_time ... Time.now + 3600)
      s2 = @summary[:all].dup
      s2[:avail_memory_avg] = Float(1000000 * system_total_wall_time) / (3600 * 41)
      summary_all_systems_ended.should eql s2
    end
    
    it "correctly handles inverted ranges" do
      t = base_time
      @systems.summary(t ... t - 1).should eql @summary[:empty]
      @systems.summary(t .. t - 1).should eql @summary[:empty]
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
      Bookie::Database::System.find_current(@sender_2).id.should eql 2
      Bookie::Database::System.find_current(@sender_2, Time.now).id.should eql 2
      Bookie::Database::System.find_current(@sender_1, base_time).id.should eql 1
    end
    
    it "correctly detects the lack of a matching system" do
      expect {
        Bookie::Database::System.find_current(@sender_1, base_time - 1.years)
      }.to raise_error(/^There is no system with hostname 'test1' that was recorded as active at /)
      @config_t1.expects(:hostname).at_least_once.returns('test1000')
      expect {
        Bookie::Database::System.find_current(@sender_1, base_time)
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
          Bookie::Database::System.find_current(sender)
        }.to raise_error(Bookie::Database::System::SystemConflictError)
        config.unstub(field)
      end
      sender.expects(:system_type).returns(Bookie::Database::SystemType.find_by_name("Standalone"))
      expect {
        Bookie::Database::System.find_current(sender)
      }.to raise_error(Bookie::Database::System::SystemConflictError)
    end
  end

  it "correctly decommissions" do
    sys = Bookie::Database::System.active_systems.find_by_name('test1')
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
      :system_type => Bookie::Database::SystemType.first,
      :start_time => base_time
    }
    
    Bookie::Database::System.new(fields).valid?.should eql true
    
    fields.each_key do |field|
      system = Bookie::Database::System.new(fields)
      system.method("#{field}=".intern).call(nil)
      system.valid?.should eql false
    end
    
    system = Bookie::Database::System.new(fields)
    system.name = ''
    system.valid?.should eql false
    
    [:cores, :memory].each do |field|
      system = Bookie::Database::System.new(fields)
      m = system.method("#{field}=".intern)
      m.call(-1)
      system.valid?.should eql false
      m.call(0)
      system.valid?.should eql true
    end
    
    system = Bookie::Database::System.new(fields)
    system.end_time = base_time
    system.valid?.should eql true
    system.end_time += 5
    system.valid?.should eql true
    system.end_time -= 10
    system.valid?.should eql false
  end
end

