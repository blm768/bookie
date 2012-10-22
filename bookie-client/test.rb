#!/usr/bin/env ruby

$LOAD_PATH.concat Dir.glob(File.join(Dir.pwd, "../*/lib"))

require 'bookie-client'

config = Bookie::Config.new('../snapshot/config.json')
config.connect
client = Bookie::Client::Client.new(config)

jobs = Bookie::Database::Job

client.print_jobs(Bookie::Filter::apply_filters(jobs, :server => 'localhost'))
