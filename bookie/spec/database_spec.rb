require 'spec_helper'

describe Bookie::Database do
  before(:all) do
    @time = Time.new
    Helpers::generate_database
  end
  
  after(:all) do
    Bookie::Database::drop_tables
  end
  
  describe Bookie::Database::Job do
    before(:each) do
      @jobs = Bookie::Database::Job
    end
    
    it "correctly filters by user" do
      jobs = @jobs.by_user_name('root').all
      jobs.length.should eql 1
      jobs[0].memory.should eql 1024
      jobs[0].user.name.should eql "root"
      jobs = @jobs.by_user_name('test').all
      jobs.length.should eql 2
      jobs.each do |job|
        job.user.name.should eql 'test'
      end
      jobs[0].user_id.should_not eql jobs[1].user_id
      jobs = @jobs.by_user_name('user').all
      jobs.length.should eql 0
    end
  end
end
=begin
  it "correctly filters by user" do
    jobs = Bookie::Filter::by_user(@jobs, "root").all
    jobs.length.should eql 1
    jobs[0].memory.should eql 1024
    jobs[0].user.name.should eql "root"
    jobs = Bookie::Filter::by_user(@jobs, "test").all
    jobs.length.should eql 2
    jobs.each do |job|
      job.user.name.should eql "test"
    end
    jobs[0].user_id.should_not eql jobs[1].user_id
    jobs = Bookie::Filter::by_user(@jobs, "user").all
    jobs.length.should eql 0
  end
  
  it "correctly filters by group" do
    jobs = Bookie::Filter::by_group(@jobs, "root").all
    jobs.length.should eql 1
    jobs[0].user.group.name.should eql "root"
    jobs = Bookie::Filter::by_group(@jobs, "admin").all
    jobs.length.should eql 2
    jobs.each do |job|
      job.user.group.name.should eql "admin"
    end
    jobs[0].user.name.should_not eql jobs[1].user.name
    jobs = Bookie::Filter::by_group(@jobs, "test").all
    jobs.length.should eql 0
  end
  
  it "correctly filters by server" do
    jobs = Bookie::Filter::by_server(@jobs, "test1")
    jobs.length.should eql 2
    jobs.each do |job|
      job.server.name.should eql "test1"
    end
    jobs = Bookie::Filter::by_server(@jobs, "test2")
    jobs.length.should eql 1
    jobs[0].server.name.should eql "test2"
    jobs = Bookie::Filter::by_server(@jobs, "test")
    jobs.length.should eql 0
  end
  
  it "correctly filters by start time" do
    #To do: expand tests?
    jobs = Bookie::Filter::by_start_time(@jobs, @time, @time + 3600 * 2)
    jobs.length.should eql 3
    jobs = Bookie::Filter::by_start_time(@jobs, @time + 1, @time + 3600 * 2)
    jobs.length.should eql 2
    jobs = Bookie::Filter::by_start_time(@jobs, Time.at(0), Time.at(3))
    jobs.length.should eql 0
  end
  
  it "correctly chains filters" do
    #To do: expand tests?
    jobs = Bookie::Filter::by_user(@jobs, "test")
    jobs = Bookie::Filter::by_start_time(jobs, @time + 3600, @time + 3601)
    jobs.length.should eql 1
    jobs[0].user.group.name.should eql "default"
  end
end
=end