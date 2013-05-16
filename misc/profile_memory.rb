#!/usr/bin/env ruby

require 'rubygems'

$LOAD_PATH << '../bookie/lib'

require 'fileutils'

require 'bookie/database'

def memory_usage
  `ps -o rss= -p #{Process.pid}`.to_i
end

config = Bookie::Config.new('../bookie/snapshot/test_config.json')
config.connect

Bookie::Database::Migration.up
begin
  sys_t = Bookie::Database::SystemType.create!(:name => 'Test', :memory_stat_type => :avg)
  sys = Bookie::Database::System.create!(
    :name => 'test',
    :system_type => sys_t,
    :start_time => Time.local(2012),
    :cores => 1,
    :memory => 1000000
  )
  group = Bookie::Database::Group.create!(:name => 'test')
  user = Bookie::Database::User.create!(:name => 'test', :group => group)
  
  n = 100000
  
  start_time = Time.local(2012)
  n.times do |i|
    start_time += 1
    Bookie::Database::Job.create!(
      :system => sys,
      :user => user,
      :start_time => start_time,
      :wall_time => 100,
      :cpu_time => 5,
      :memory => 1000,
      :exit_code => 0
    )
  end
  #GC::Profiler.enable
  old_mem = GC.stat[:heap_used]
  jobs = Bookie::Database::Job.all
  puts "Memory for #{n} jobs: #{GC.stat[:heap_used] - old_mem}"
  #puts GC::Profiler.result
  #GC::Profiler.disable
ensure
  FileUtils.rm('test.sqlite')
end
