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

  #Creates summaries under different conditions
  def create_summaries(obj, base_time)
    base_start = base_time
    base_end   = base_time + 40.hours
    summaries = {
      :all => obj.summary,
      :all_constrained => obj.summary(base_start ... base_end),
      :wide => obj.summary(base_start - 1.hours ... base_end + 1.hours),
      #TODO: push this farther forward?
      :clipped => obj.summary(base_start + 30.minutes ... base_start + 25.hours),
      :empty => obj.summary(base_start ... base_start),
    }

    #TODO: move?
    if obj.respond_to?(:by_command_name)
      summaries[:all_filtered] = obj.by_command_name('vi').summary(base_start ... base_end)
    end

    summaries
  end

  BASE_TIME = Time.utc(2012)
  #To get around the "formal argument cannot be a constant" error
  def base_time
    BASE_TIME
  end

  #Create test database
  def self.generate_database
    groups = {}
    group_names = ['root', 'default', 'admin', 'admin']
    group_names[0 .. 2].each do |name|
      group = Bookie::Database::Group.create!(:name => name)
      groups[name] = group
    end

    users = []
    user_names = ['root', 'test', 'test', 'blm768']
    user_names.each_with_index do |name, i|
      user = Bookie::Database::User.new
      user.name = name
      user.group = groups[group_names[i]]
      user.save!
      users << user
    end

    system_types = [
      Bookie::Database::SystemType.create!(
        :name => 'Standalone',
        :memory_stat_type => :avg
      ),
      Bookie::Database::SystemType.create!(
        :name => 'TORQUE cluster',
        :memory_stat_type => :max
      ),
    ]

    systems = []
    system_names = ['test1', 'test1', 'test2', 'test3']
    system_names.each_with_index do |name, i|
      system = Bookie::Database::System.create!(
        :name => name,
        :system_type => system_types[i % 2],
        :start_time => BASE_TIME + (10.hours * i),
        :cores => 2,
        :memory => 1000000
      )
      systems << system
    end
    systems[0].end_time = systems[1].start_time
    systems[0].save!

    40.times do |i|
      job = Bookie::Database::Job.new
      job.user = users[i % users.length]
      job.system = systems[i / 10]
      if i & 1 == 0
        job.command_name = 'vi'
      else
        job.command_name = 'emacs'
      end
      job.start_time = BASE_TIME + i.hours
      job.wall_time = 1.hours
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

  config.mock_with(:mocha)

  config.before(:suite) do
    Helpers.test_config = Bookie::Config.new('snapshot/test_config.json')
    Helpers.test_config.connect

    ActiveRecord::Migration.verbose = false
    Bookie::Database.migrate
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

