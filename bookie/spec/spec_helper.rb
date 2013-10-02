if ENV['COVERAGE']
  require 'simplecov'
  SimpleCov.start
end

#TODO: remove?
$LOAD_PATH.concat Dir.glob(File.join(Dir.pwd, "../*/lib"))

require 'fileutils'
require 'mocha/api'

require 'bookie'

class IOMock
  def initialize
    @buf = ""
  end
  
  def puts(str)
    @buf << str.to_s
    @buf << "\n"
  end
  
  def write(str)
    @buf << str.to_s
  end
  
  def printf(format, *args)
    @buf << sprintf(format, *args)
  end
  
  def buf
    @buf
  end
end

module Helpers
  #Just shorthand for the connection's #begin_transaction method
  def begin_transaction
    ActiveRecord::Base.connection.begin_transaction
  end

  def rollback_transaction
    ActiveRecord::Base.connection.rollback_transaction
  end

  def create_summaries(obj, base_time)
    start_time_1 = base_time
    end_time_1   = base_time + 40.hours
    #TODO: push this farther forward?
    start_time_2 = base_time + 30.minutes
    end_time_2 = base_time + 25.hours
    summaries = {
      :all => obj.summary,
      :all_constrained => obj.summary(start_time_1 .. end_time_1),
      :clipped => obj.summary(start_time_2 ... end_time_2),
      :empty => obj.summary(Time.at(0) ... Time.at(0)),
    }

    #TODO: move?
    if obj.respond_to?(:by_command_name)
      summaries[:all_filtered] = obj.by_command_name('vi').summary(start_time_1 ... end_time_1)
    end
    
    summaries
  end
  
  def test_system_relation_identity(system, relation_ids)
    t = system.system_type
    method_object_id = Object.instance_method(:object_id)
    if relation_ids.include?(t)
      relation_ids[t].should eql method_object_id.bind(t).call
    else
      relation_ids[t] = method_object_id.bind(t).call
    end
  end

  BASE_TIME = Time.utc(2012)
  #To get around the "formal argument cannot be a constant" error
  def base_time
    BASE_TIME
  end

  def self.generate_database
    #Create test database
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
      unless users[[name, group_names[i]]]
        user = Bookie::Database::User.new
        user.name = name
        user.group = groups[group_names[i]]
        user.save!
        users[name] ||= {}
        users[[name, group_names[i]]] = user
      end
    end
    system_types = [
      Bookie::Database::SystemType.create!(
        :name => 'Standalone',
        :memory_stat_type => :avg),
      Bookie::Database::SystemType.create!(
        :name => 'TORQUE cluster',
        :memory_stat_type => :max)]
    systems = []
    system_names = ['test1', 'test1', 'test2', 'test3']
    system_names.each_index do |i|
      name = system_names[i]
      unless systems.include?name
        system = Bookie::Database::System.create!(
          :name => name,
          :system_type => system_types[i % 2],
          :start_time => BASE_TIME + (36000 * i),
          :cores => 2,
          :memory => 1000000)
        systems << system
      end
    end
    systems[0].end_time = BASE_TIME + 36000
    systems[0].save!
    for i in 0 ... 40 do
      job = Bookie::Database::Job.new
      job.user = users[[user_names[i % user_names.length], group_names[i % user_names.length]]]
      job.system = systems[i / 10]
      if i & 1 == 0
        job.command_name = 'vi'
      else
        job.command_name = 'emacs'
      end
      job.start_time = BASE_TIME + 3600 * i
      job.wall_time = 3600
      job.cpu_time = 100
      job.memory = 200
      job.exit_code = i & 1
      job.save!
    end
  end

  def with_utc
    prev = ENV['TZ']
    ENV['TZ'] = 'UTC'
    yield
  ensure
    ENV['TZ'] = prev
  end

  def test_config
    Helpers.test_config
  end

  def self.test_config
    @test_config
  end

  def self.test_config=(config)
    @test_config = config
  end
end

RSpec.configure do |config|
  config.include Helpers

  #config.fail_fast = true

  config.mock_with(:mocha)

  config.before(:suite) do
    Helpers.test_config = Bookie::Config.new('snapshot/test_config.json')
    Helpers.test_config.connect

    Bookie::Database::Migration.up
    Helpers.generate_database
  end

  #Each group/example is wrapped in a transaction to make sure that tests
  #get clean databases.
  config.before(:all) do
    begin_transaction
  end
  
  config.after(:all) do
    rollback_transaction
  end

  config.before(:each) do
    begin_transaction
  end
  
  config.after(:each) do
    rollback_transaction
  end
end

