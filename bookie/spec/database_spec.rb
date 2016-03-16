require 'spec_helper'

include Bookie::Database

describe Bookie::Database do
  #The other database-related tests implicitly test the success of the migrations,
  #so we'll ignore that aspect here.

  let(:latest_version) { ActiveRecord::Migrator.migrations(MIGRATIONS_PATH).last.version }

  it { expect(Dir.exist?(MIGRATIONS_PATH)) }

  describe '#latest_version' do
    it { expect(Bookie::Database::latest_version).to eql latest_version }
  end

  describe "#migrate" do
    it "runs migrations" do
      (0 .. latest_version).each do |version|
        ActiveRecord::Migrator.expects(:migrate).with(MIGRATIONS_PATH, version)
        Bookie::Database.migrate(version)
      end
    end

    it "migrates without errors" do
      Bookie::Database.migrate(0)
      Bookie::Database.migrate(latest_version)
      Bookie::Database.migrate(0)
    end

    #TODO: remove this functionality?
    it "picks the latest version as the default" do
      ActiveRecord::Migrator.expects(:migrate).with(MIGRATIONS_PATH, latest_version)
      Bookie::Database.migrate
    end
  end

  describe Bookie::Database::Config do
    it "connects to the database" do
      ActiveRecord::Base.expects(:establish_connection)
      db_config.connect
      expect(ActiveRecord::Base.time_zone_aware_attributes).to eql true
      expect(ActiveRecord::Base.default_timezone).to eql :utc
    end
  end
end
