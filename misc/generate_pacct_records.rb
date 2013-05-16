#!/usr/bin/env ruby
require 'date'
require 'pacct'

filename = 'snapshot/pacct_generated'
log = Pacct::Log.new(filename, "wb")

count = 1000

#hostnames = ['test1', 'test2', 'test3']
users = ['root', 'bin', 'daemon']
groups = ['root', 'bin', 'daemon']

base_time = Time.utc(2012).to_time.to_i

rand = Random.new(Time.new.to_i)

for i in 1 .. count
  e = Pacct::Entry.new
  e.command_name = "test"
  e.process_id = i
  e.user_name = users[rand.rand(users.length).to_i]
  e.group_name = groups[rand.rand(groups.length).to_i]
  end_time = base_time + i * 20
  wall_time = rand.rand(20).to_i
  cpu_time = rand.rand(10).to_i
  e.start_time = end_time - wall_time
  e.wall_time = wall_time
  e.user_time = cpu_time
  e.memory = rand.rand(250) + 800
  e.exit_code = rand.rand(2).to_i
  log.write_entry(e)
end
