require 'spec_helper'

describe Bookie::Database::Lock do
  it "finds locks" do
    Lock = Bookie::Database::Lock
    expect(Lock[:users]).to_not eql nil
    expect(Lock[:users].name).to eql 'users'
    expect(Lock[:groups]).to_not eql nil
    expect(Lock[:groups].name).to eql 'groups'
    expect { Lock[:dummy] }.to raise_error(ActiveRecord::RecordNotFound)
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
    #    expect(Time.now - t).to >= 0.5
    #  }
    #  sleep(1)
    #end
    #thread.join
  #end

  it "validates fields" do
    lock = Bookie::Database::Lock.new
    lock.name = nil
    expect(lock.valid?).to eql false
    lock.name = ''
    expect(lock.valid?).to eql false
    lock.name = 'test'
    expect(lock.valid?).to eql true
  end
end
