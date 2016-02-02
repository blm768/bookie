require 'spec_helper'

require 'active_record'

describe Bookie::Config do
  it "loads correct data" do
    config = Bookie::Config.new('snapshot/test_config.json')

    expect(config.db_type).to eql "sqlite3"
    expect(config.server).to eql "localhost"
    expect(config.port).to eql 8080
    expect(config.database).to eql ":memory:"
    expect(config.username).to eql "blm768"
    expect(config.password).to eql "test"
    expect(config.excluded_users).to eql Set.new(["root"])
    expect(config.hostname).to eql "localhost"
    expect(config.cores).to eql 8
    expect(config.memory).to eql 8000000
    expect(config.system_type).to eql 'torque_cluster'
  end

  it "correctly verifies types" do
    config = Bookie::Config.new('snapshot/default.json')
    config.verify_type("abc", "test", String)
    expect { config.verify_type("abc", "test", Fixnum) }.to raise_error(TypeError, 'Invalid data type String for JSON field "test": Fixnum expected')
  end

  it "sets correct defaults" do
    dconfig = Bookie::Config.new('snapshot/default.json')

    expect(dconfig.port).to eql nil
    expect(dconfig.excluded_users).to eql Set.new([])
  end

  it 'correctly handles missing fields' do
    fields = JSON.parse(File.read('snapshot/default.json'))
    fields.keys.each do |key|
      removed = fields.delete(key)
      JSON.stubs(:parse).returns(fields)
      expect { Bookie::Config.new('snapshot/default.json') }.to raise_error(/^Field "[\w ]+" must have a non-null value.$/)
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
    expect(ActiveRecord::Base.time_zone_aware_attributes).to eql true
    expect(ActiveRecord::Base.default_timezone).to eql :utc
  end
end
