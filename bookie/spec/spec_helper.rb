if ENV['COVERAGE']
  require 'simplecov'
  SimpleCov.start
end

require 'fileutils'
require 'mocha_standalone'

require 'bookie'

RSpec.configure do |config|
  config.mock_with(:mocha)
end

module Helpers
  extend self

  def generate_database
    base_time = Time.new(2012, 2, 1)
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
    systems = {}
    system_names = ['test1', 'test1', 'test2', 'test3']
    system_names.each_index do |i|
      name = system_names[i]
      unless systems.include?name
        system = Bookie::Database::System.create!(
          :name => name,
          :system_type => system_types[i & 1],
          :start_time => Time.new(2012, 2 * i + 1, 1),
          :cores => 2,
          :memory => 1000000)
        systems[name] = system
      end
    end
    first_system = systems['test1']
    first_system.end_time = Time.new(2012, 3, 1)
    first_system.save!
    for i in 0 ... 100 do
      job = Bookie::Database::Job.new
      job.user = users[[user_names[i % user_names.length], group_names[i % user_names.length]]]
      job.system = systems[system_names[i % system_names.length]]
      job.start_time = base_time + 3600 * i
      job.end_time = job.start_time + 3600
      job.wall_time = 3600
      job.cpu_time = 100 * i
      job.memory = (i + 1) * 1024
      job.exit_code = i & 1
      job.save!
    end
  end
end