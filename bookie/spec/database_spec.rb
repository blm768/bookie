require 'spec_helper'

include Bookie::Database

#Manually updated when we add new migrations
#TODO: find a better way to do this?
LATEST_MIGRATION = 1

describe Bookie::Database do
  #The other database-related tests implicitly test the success of the migrations,
  #so we'll ignore that aspect here.

  it "has a migration directory which exists" do
    expect(Dir.exist?(MIGRATIONS_PATH))
  end

  describe '#latest_version' do
    it { expect(Bookie::Database::latest_version).to eql LATEST_MIGRATION }

    #TODO: do we care about this?
    it "skips invalid migrations"
  end

  describe "#migrate" do
    it "runs migrations" do
      (0 .. LATEST_MIGRATION).each do |version|
        ActiveRecord::Migrator.expects(:migrate).with(MIGRATIONS_PATH, version)
        Bookie::Database.migrate(version)
      end
    end

    it "migrates up and down without errors" do
      Bookie::Database.migrate(0)
      Bookie::Database.migrate(LATEST_MIGRATION)
      Bookie::Database.migrate(0)
    end

    #TODO: remove this functionality?
    it "picks the current version as the default" do
      ActiveRecord::Migrator.expects(:migrate).with(MIGRATIONS_PATH, LATEST_MIGRATION)
      Bookie::Database.migrate
    end
  end
end
