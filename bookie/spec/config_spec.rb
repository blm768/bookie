require 'spec_helper'

require 'active_record'

describe Bookie::Config do
  it "loads correct data" do
    config = Bookie::Config.new('snapshot/test_config.json')
    
    config.db_type.should eql "sqlite3"
    config.server.should eql "localhost"
    config.port.should eql 8080
    config.database.should eql "bookie_test"
    config.username.should eql "blm768"
    config.password.should eql "test"
    config.excluded_users.should eql Set.new(["root"])
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
  
  it "attempts to connect to the database" do
    config = Bookie::Config.new('snapshot/test_config.json')
    ActiveRecord::Base.stubs(:logger=).returns(nil).at_least_once
    ActiveRecord::Base.stubs(:establish_connection).returns(nil).at_least_once
    config.connect
  end
end