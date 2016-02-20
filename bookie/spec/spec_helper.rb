begin
  this_dir = File.dirname(__FILE__)
  $LOAD_PATH << File.join(this_dir, '..', 'lib')
  $LOAD_PATH << this_dir
end

if ENV['COVERAGE']
  require 'simplecov'
  SimpleCov.start
end

require 'fileutils'
require 'mocha/api'

require 'bookie'

module Helpers
  #Just shorthand for the connection's #begin_transaction method
  def begin_transaction
    ActiveRecord::Base.connection.begin_transaction
  end

  def rollback_transaction
    ActiveRecord::Base.connection.rollback_transaction
  end

  BASE_TIME = Time.utc(2012)
  #To get around the "formal argument cannot be a constant" error
  def base_time
    BASE_TIME
  end

  #Create test database
  def self.generate_database
    users = []
    user_names = ['root', 'test', 'test2', 'blm']
    user_names.each_with_index do |name, i|
      users << Bookie::Database::User.create!(id: i + 1, name: name)
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
    ['test1', 'test2', 'test3'].each_with_index do |name, i|
      system = Bookie::Database::System.create!(
        name: name,
        system_type: system_types[i % 2]
      )

      capacity = Bookie::Database::SystemCapacity.create!(
        system: system,
        start_time: BASE_TIME + (10.hours * i),
        cores: 2,
        memory: 1000000
      )
      systems << system
    end

    #Give the first system two capacity entries.
    systems[0].decommission!(systems[1].current_capacity.start_time)
    capacity = systems[2].current_capacity.dup
    capacity.system = systems[0]
    capacity.save!

    SystemCapacity.find_each do |capacity|
      system = capacity.system
      10.times do |i|
        job = Bookie::Database::Job.new
        job.user = users[i % users.length]
        job.system = system
        if i & 1 == 0
          job.command_name = 'vi'
        else
          job.command_name = 'emacs'
        end
        job.start_time = capacity.start_time + i.hours
        job.wall_time = 1.hours
        job.cpu_time = 100
        job.memory = 200
        job.exit_code = i & 1
        job.save!
      end
    end
  end

  #Runs the provded block with the time zone set to UTC
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
