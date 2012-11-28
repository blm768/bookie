require 'spec_helper'

require 'active_record'

describe Bookie::Config do
  it "loads correct data" do
    config = Bookie::Config.new('snapshot/test_config.json')
    
    config.db_type.should eql "sqlite3"
    config.server.should eql "localhost"
    config.port.should eql 8080
    config.database.should eql "spec/test.sqlite"
    config.username.should eql "blm768"
    config.password.should eql "test"
    config.excluded_users.should eql Set.new(["root"])
    config.hostname.should eql "localhost"
    config.cores.should eql 8
    config.memory.should eql 8000000
    config.maximum_idle.should eql 5
    config.system_type.should eql 'torque_cluster'
  end
  
  it "correctly verifies types" do
    config = Bookie::Config.new('snapshot/default.json')
    config.verify_type("abc", "test", String)
    expect { config.verify_type("abc", "test", Fixnum) }.to raise_error(TypeError, 'Invalid data type String for JSON field "test": Fixnum expected')
  end
  
  it "sets correct defaults" do
    dconfig = Bookie::Config.new('snapshot/default.json')
    
    dconfig.port.should eql nil
    dconfig.excluded_users.should eql Set.new([]) 
    dconfig.maximum_idle.should eql 3
  end
  
  it 'correctly handles missing fields' do
    fields = JSON.parse(File.read('snapshot/default.json'))
    fields.keys.each do |key|
      removed = fields.delete(key)
      JSON.stubs(:parse).returns(fields)
      expect { Bookie::Config.new('snapshot/default.json') }.to raise_error
      fields[key] = removed
    end
    JSON.stubs(:parse).returns(fields)
    #This should not raise an error.
    Bookie::Config.new('snapshot/default.json')
  end
  
  it "configures and connects to the database" do
    config = Bookie::Config.new('snapshot/test_config.json')
    ActiveRecord::Base.expects(:establish_connection)
    config.connect
    ActiveRecord::Base.time_zone_aware_attributes.should eql true
    ActiveRecord::Base.default_timezone.should eql :utc
  end
end