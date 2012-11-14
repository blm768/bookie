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
  def generate_database
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
    systems = {}
    system_names = ['test1', 'test1', 'test2', 'test3']
    system_names.each_index do |i|
      name = system_names[i]
      unless systems.include?name
        system = Bookie::Database::System.create!(
          :name => name,
          :system_type => i & 1,
          :cores => 2,
          :memory => 1000000)
        systems[name] = system
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
  end
end