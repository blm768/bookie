#!/usr/bin/env ruby
require 'date'

f = File.open('snapshot/server_priv/accounting/20121008', 'w')

count = 1000

hostnames = ['test1', 'test2', 'test3']
users = ['abc1', 'abc2', 'abc3']
groups = ['group1', 'group2', 'group3']

base_time = Date.new(2012, 1, 1).to_time.to_i

rand = Random.new(Time.new.to_i)

for i in 1 .. count
  f.write(";E;")
  f.write("#{i}[0].#{hostnames[rand.rand(hostnames.length).to_i]};")
  f.write("jobname=#{i} ")
  f.write("user=#{users[rand.rand(users.length).to_i]} ")
  f.write("group=#{groups[rand.rand(groups.length).to_i]} ")
  end_time = base_time + i * 20
  wall_time = rand.rand(20).to_i
  cpu_time = rand.rand(10).to_i
  f.write("start=#{end_time - wall_time} ")
  f.write("resources_used.walltime=00:00:#{wall_time} ")
  f.write("resources_used.cput=00:00:#{cpu_time} ")
  f.write("resources_used.mem=#{rand.rand(250) + 800}kb ")
  f.write("resources_used.vmem=0kb ")
  f.write("Exit_status=#{rand.rand(2).to_i} ")
  f.puts
end