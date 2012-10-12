#!/usr/bin/env rake

def each_gem
  Dir.entries('.').each do |entry|
    if !File.file?(File.join(entry, "config/routes.rb")) && File.file?(File.join(entry, "Gemfile"))
      curdir = Dir.pwd
      Dir.chdir(entry)
      yield entry
      Dir.chdir(curdir)
    end
  end
end

task :default => :spec

task :spec do
  each_gem do
    puts `rake install`
    puts `rake`
  end
end
