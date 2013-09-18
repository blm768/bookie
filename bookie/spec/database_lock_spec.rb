require 'spec_helper'

describe Bookie::Database do
  Helpers.init_database(self)

  describe Bookie::Database::Lock do
    it "finds locks" do
      Lock = Bookie::Database::Lock
      Lock[:users].should_not eql nil
      Lock[:users].name.should eql 'users'
      Lock[:groups].should_not eql nil
      Lock[:groups].name.should eql 'groups'
      expect { Lock[:dummy] }.to raise_error("Unable to find lock 'dummy'")
    end
    
    it "locks records (will probably fail if the testing DB doesn't support row locks)" #do
      #lock = Bookie::Database::Lock[:users]
      #thread = nil
      #lock.synchronize do
      #  thread = Thread.new {
      #    t = Time.now
      #    ActiveRecord::Base.connection_pool.with_connection do
      #      lock.synchronize do
      #        Bookie::Database::User.first
      #      end
      #    end
      #    (Time.now - t).should >= 0.5
      #  }
      #  sleep(1)
      #end
      #thread.join
    #end
    
    it "validates fields" do
      lock = Bookie::Database::Lock.new
      lock.name = nil
      lock.valid?.should eql false
      lock.name = ''
      lock.valid?.should eql false
      lock.name = 'test'
      lock.valid?.should eql true
    end
  end
end

