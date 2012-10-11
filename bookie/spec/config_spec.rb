require 'spec_helper'

describe Bookie::Config do
  it "loads correct data" do
    config = Bookie::Config.new('snapshot/config.json')
    
    config.server.should eql "localhost"
    config.port.should eql 8080
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
    dconfig.port.should eql nil
    dconfig.username.should eql "root"
    dconfig.password.should eql ""
    dconfig.excluded_users.should eql Set.new([])
  end
  
  it 'correctly handles a missing "Server" field' do
    expect { Bookie::Config.new('snapshot/empty.json') }.to raise_error("No database server specified")
  end
end