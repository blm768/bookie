require 'spec_helper'

describe Bookie::Database do
  before(:all) do
    begin
      Helpers::generate_database
    rescue => e
      raise StandardError.new(([e.to_s] + e.backtrace).join("\n"))
    end
  end
  
  after(:all) do
    #Bookie::Database::drop_tables
  end
  
  describe Bookie::Database::Job do
    before(:each) do
      @jobs = Bookie::Database::Job
      @base_time = @jobs.first.start_time
    end
    
    it "correctly filters by user" do
      jobs = @jobs.by_user_name('root').all
      jobs.length.should eql 25
      jobs[0].memory.should eql 1024
      jobs[0].user.name.should eql "root"
      jobs = @jobs.by_user_name('test').order(:end_time).all
      jobs.length.should eql 50
      jobs.each do |job|
        job.user.name.should eql 'test'
      end
      jobs[0].user_id.should_not eql jobs[-1].user_id
      jobs = @jobs.by_user_name('user').all
      jobs.length.should eql 0
    end
  
    it "correctly filters by group" do
      jobs = @jobs.by_group_name("root").all
      jobs.length.should eql 25
      jobs[0].user.group.name.should eql "root"
      jobs = @jobs.by_group_name("admin").order(:start_time).all
      jobs.length.should eql 50
      jobs.each do |job|
        job.user.group.name.should eql "admin"
      end
      jobs[0].user.name.should_not eql jobs[1].user.name
      jobs = @jobs.by_group_name("test").all
      jobs.length.should eql 0
    end
    
    it "correctly filters by system" do
      jobs = @jobs.by_system_name('test1')
      jobs.length.should eql 50
      jobs = @jobs.by_system_name('test3')
      jobs.length.should eql 25
    end
    
    it "correctly filters by start time" do
      #To do: expand tests?
      jobs = @jobs.by_start_time_range(@base_time, @base_time + 3600 * 2 + 1)
      jobs.length.should eql 3
      jobs = @jobs.by_start_time_range(@base_time + 1, @base_time + 3600 * 2)
      jobs.length.should eql 1
      jobs = @jobs.by_start_time_range(Time.at(0), Time.at(3))
      jobs.length.should eql 0
    end
    
    it "correctly chains filters" do
      #To do: expand tests?
      jobs = @jobs.by_user_name("test")
      jobs = jobs.by_start_time_range(@base_time + 3600, @base_time + 3601)
      jobs.length.should eql 1
      jobs[0].user.group.name.should eql "default"
    end
  end
end
