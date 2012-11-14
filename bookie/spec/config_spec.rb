require 'spec_helper'

require 'active_record'

describe Bookie::Config do
  it "loads correct data" do
    config = Bookie::Config.new('snapshot/test_config.json')
    
    config.db_type.should eql "sqlite3"
    config.server.should eql "localhost"
    config.port.should eql 8080
    config.database.should eql "snapshot/bookie_test.sqlite"
    config.username.should eql "blm768"
    config.password.should eql "test"
    config.excluded_users.should eql Set.new(["root"])
    config.hostname.should eql "localhost"
    config.maximum_idle.should eql 5
    config.system_type.should eql 'standalone'
  end
  
  it "correctly parses command-line arguments" do
    config = Bookie::Config.new('snapshot/test_config.json')
    opts = OptionParser.new
    config.parse_options(opts)
    opts.parse!(%w{-h github.com -c 256 -m 100 -t none})
    
    config.hostname.should eql 'github.com'
    config.cores.should eql 256
    config.memory.should eql 100
    config.system_type.should eql 'none'
  end
  
  it "correctly verifies types" do
    config = Bookie::Config.new('snapshot/default.json')
    config.verify_type("abc", "test", String)
    expect { config.verify_type("abc", "test", Fixnum) }.to raise_error(TypeError, 'Invalid data type String for JSON field "test": Fixnum expected')
  end
  
  it "sets correct defaults" do
    dconfig = Bookie::Config.new('snapshot/default.json')
    
    dconfig.db_type.should eql "mysql2"
    dconfig.port.should eql nil
    dconfig.database.should eql "bookie"
    dconfig.username.should eql "root"
    dconfig.password.should eql ""
    dconfig.excluded_users.should eql Set.new([])
  end
  
  it 'correctly handles a missing "Server" field' do
    expect { Bookie::Config.new('snapshot/empty.json') }.to raise_error("No database server specified")
  end
  
  it 'requires the system type to be set' do
    expect { Bookie::Config.new('snapshot/default.json').system_type }.to raise_error("No system type specified")
  end
  
  it "attempts to connect to the database" do
    config = Bookie::Config.new('snapshot/test_config.json')
    ActiveRecord::Base.stubs(:establish_connection).returns(nil).at_least_once
    config.connect
  end
end