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

desc "Synchronize snapshot files from the master snapshot directory"
task :sync_snapshots do
  Dir.glob('*/snapshot/**/*').each do |entry|
    master_snapshot = entry.sub(/^.*\/snapshot/, "snapshot")
    next unless File.file?(entry)
    unless File.file?(master_snapshot)
      $stderr.puts "Warning: file '#{entry}' has no counterpart in the master snapshot directory."
      next
    end
    FileUtils.copy(master_snapshot, entry)
  end
end