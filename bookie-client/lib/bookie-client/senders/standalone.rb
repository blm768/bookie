require 'fileutils'
require 'pacct'

module Bookie
  module Sender
    #Represents a client that returns data from a standalone Linux system
    class Standalone < Sender
      #Yields each job in the log
      def each_job(date = nil)
        #To do: modify for production.
        base_dir = 'snapshot'
        base_filename = File.join(base_dir, 'pacct')
        log_base_filename = File.join(@config.log_dir, 'var/account/pacct')
        #Are we reading an old log?
        if date
          filename = log_base_filename + date.strftime(".%Y.%m.%d")
          file = Pacct::File.new(filename)
          file.each_entry do |job|
            yield job
          end
        else
          begin
            file = Pacct::File.new(base_filename)
            start = 0
            current_entry = nil
            #If there's a bookmark from previous processing, use it.
            start = @config.bookmarks.delete(system_type_name)
            #If the bookmark exists, make sure it's an integer.
            start = Integer(start) if start
            rotation_file = nil
            rotation_end_time = Time.at(0)
            file.each_entry(start) do |job, index|
              current_entry = index
              job_end_time = job.start_time + job.wall_time
              #Is it time for a new rotation file?
              if job_end_time >= rotation_end_time || !rotation_file
                rotation_start_date = job_end_time.to_date
                rotation_end_time = rotation_start_date.next_day.to_time
                rotation_filename = log_base_filename + rotation_start_date.strftime(".%Y.%m.%d")
                mode = if File.exists?(rotation_filename) then 'r+b' else 'w+b' end
                rotation_file = Pacct::File.new(rotation_filename, mode)
                #Did this file already contain data?
                if rotation_file.num_entries > 0
                  #See if we can just append.
                  last = rotation_file.last_entry
                  if last.start_time + last.wall_time >= job.start_time + job.wall_time
                    #To do: clearer message?
                    raise "Error: log file '#{rotation_filename}' contains entries newer than those in #{base_filename}."
                  end
                end
              end
              yield job
              rotation_file.write_entry(job)
            end
          rescue => e
            #Set a bookmark so we can start here next time.
            if current_entry
              @config.bookmarks[system_type_name] = current_entry
            end
            raise e
          end
          #To do: uncomment for production.
          #To do: verify that this doesn't kill accounting.
          #FileUtils.rm(base_filename)
        end
      end
      
      def flush_jobs(date)
        each_job(date) do |job|
          yield job
        end
      end
      
      def system_type_name
        return "Standalone (Linux)"
      end
      
      def memory_stat_type
        return :avg
      end
    end
  end
end