require 'spec_helper'

require 'fileutils'

require 'bookie/filter'

describe Bookie::Filter do
  before(:all) do
    @time = Time.new
    #Create test database
    FileUtils.rm('test.sqlite') if File.exists?('test.sqlite')
    ActiveRecord::Base.establish_connection(
        :adapter  => 'sqlite3',
        :database => 'test.sqlite')
    Bookie::Database::create_tables
    groups = {}
    group_names = ['root', 'default', 'admin', 'admin']
    group_names.each do |name|
      unless groups[name]
        group = Bookie::Database::Group.new
        group.name = name
        group.save!
        groups[name] = group
      end
    end
    users = {}
    user_names = ['root', 'test', 'test', 'blm768']
    user_names.each_index do |i|
      name = user_names[i]
      unless users[name] && users[name][group_names[i]]
        user = Bookie::Database::User.new
        user.name = name
        user.group = groups[group_names[i]]
        user.save!
        users[name] ||= {}
        users[name][group_names[i]] = user
      end
    end
    servers = {}
    server_names = ['test1', 'test1', 'test2', 'test3']
    server_names.each_index do |i|
      name = server_names[i]
      unless servers.include?name
        server = Bookie::Database::Server.new
        server.name = name
        server.server_type = i & 1
        server.save!
        servers[name] = server
      end
    end
    for i in 0 ... user_names.length do
      job = Bookie::Database::Job.new
      job.user = users[user_names[i]][group_names[i]]
      job.server = servers[server_names[i]]
      job.start_time = @time + 3600 * i
      job.end_time = job.start_time + 3600
      job.wall_time = 3600
      job.cpu_time = 100 * i
      job.memory = (i + 1) * 1024
      job.save!
    end
    @jobs = Bookie::Database::Job
  end
  
  after(:all) do
    #To make sure this won't throw when the table structure is correct
    Bookie::Database::delete_tables
    FileUtils.rm('test.sqlite') if File.exists?('test.sqlite')
  end
  
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