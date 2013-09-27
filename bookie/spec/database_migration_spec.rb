require 'spec_helper'

include Bookie::Database::Migration

MIGRATION_CLASSES = [
  CreateUsers,
  CreateGroups,
  CreateSystems,
  CreateSystemTypes,
  CreateJobs,
  CreateJobSummaries,
  CreateLocks,
]
  
describe Bookie::Database::Migration do
  #The other database-related tests implicitly test the "up" methods of the individual migrations.

 
  describe "#up" do
    it "brings up all migrations" do
      MIGRATION_CLASSES.each { |c| c.any_instance.expects(:up) }
      Bookie::Database::Migration.up
    end
  end

  describe "#down" do
    it "brings down all migrations" do
      MIGRATION_CLASSES.each { |c| c.any_instance.expects(:down) }
      Bookie::Database::Migration.down
    end
  end

  MIGRATION_CLASSES.each do |klass|
    describe klass do
      describe "#down" do
        it "deletes the table" do
          migration = klass.new
          migration.expects(:drop_table)
          migration.down
        end
      end
    end
  end
end
