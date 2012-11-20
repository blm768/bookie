if ENV['COVERAGE']
  require 'simplecov'
  SimpleCov.start
end

require 'fileutils'
require 'mocha_standalone'

require 'bookie'

RSpec.configure do |config|
  config.mock_with(:mocha)
  
  config.before(:all) do
    @config = Bookie::Config.new('snapshot/test_config.json')
    @config.connect
    Bookie::Database::create_tables
  end
  
  config.after(:all) do
    Bookie::Database::drop_tables
  end
end

module Helpers
  extend self

  def generate_database
    base_time = Time.new(2012)
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
          :system_type => system_types[i & 1],
          :start_time => base_time + (36000 * i),
          :cores => 2,
          :memory => 1000000)
        systems << system
      end
    end
    systems[0].end_time = base_time + 36000
    systems[0].save!
    for i in 0 ... 40 do
      job = Bookie::Database::Job.new
      job.user = users[[user_names[i % user_names.length], group_names[i % user_names.length]]]
      job.system = systems[i / 10]
      job.start_time = base_time + 3600 * i
      job.wall_time = 3600
      job.cpu_time = 100
      job.memory = (i + 1) * 1024
      job.exit_code = i & 1
      job.save!
    end
  end
end