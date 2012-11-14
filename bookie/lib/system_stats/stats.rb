require 'json'
require 'set'

require 'system_stats/utmp'

module SystemStats
  #This class provides methods to obtain useful system statistics on the local machine.
  class LocalStats
    #Gets the numeric value from a line in /proc/meminfo; used by mem_stats().
    def get_mem_stats_value(line)
      Integer(/\d+/.match(line)[0])
    end
    private   :get_mem_stats_value

    #Returns the number of processing cores on the system.
    def num_cores()
      num = 0

      begin
        cpuData = File.open('/proc/cpuinfo', "r") 
        cpuData.each_line do |line|
          line.chomp!
          num += 1 if /^processor\s*:\s*\d$/ =~ line
        end
      ensure
        cpuData.close unless cpuData.nil?
      end
      num
    end

    #Returns the 5-, 10-, and 15-minute load averages as an array of 3 floating-point values.
    def load_stats()
      loads = {}
      begin
        loadavg = File.open('/proc/loadavg')
        loads = loadavg.readline.split(' ')[0 ... 3].map{|str| Integer(Float(str) * 100)}
      ensure
        loadavg.close unless loadavg.nil?
      end
      return loads
    end
    
    #Returns a hash containing disk space percentages for each monitored mount point
    #To do: finish transitional work
    def disk_usage(monitored_mounts)
      return {} if monitored_mounts.empty?
      
      disks = {}

      monitored_mounts.each do |disk|
        disks[disk] = nil
      end

      diskData = `#{@config.df_command}`
      
      diskData.each_line do |line|
        fields = line.split(' ')
        name = fields[5 .. -1].join
        disks[name] = Integer(Float(fields[4][0 .. -2])) if monitored_mounts.include? name
      end

      return disks
    end

    #Returns a hash containing the following elements:
    #
    #* "Total": the total amount of physical memory
    #* "Cached": the amount of cached physical memory
    #* "Free": the amount of free physical memory as a percentage of total physical memory
    #* "Swap": the total amount of swap space
    #* "SwapCached": the amount of cached swap space
    #* "SwapFree": the amount of free swap space as a percentage of total swap space
    def mem_stats()
      memTotal = nil
      memFree = nil
      swapTotal = nil
      swapFree = nil
      memCached = nil
      swapCached = nil
      
      File.open('/proc/meminfo') do |file|
        file.each_line do |line|
          case line
            when /^MemTotal:\s/
              memTotal = get_mem_stats_value(line)
            when /^MemFree:\s/
              memFree = get_mem_stats_value(line)
            when /^SwapTotal:\s/
              swapTotal = get_mem_stats_value(line)
            when /^SwapFree:\s/
              swapFree = get_mem_stats_value(line)
            when /^Cached:\s/
              memCached = get_mem_stats_value(line)
            when /^SwapCached:\s/
              swapCached = get_mem_stats_value(line)
          end
        end
      end

      if memFree
        if memTotal
          memFree = Integer(Float(memFree) / memTotal * 100)
        else
          memFree = nil
        end
      end

      if swapFree
        if swapTotal
          swapFree = Integer(Float(swapFree) / swapTotal * 100)
        else
          swapFree = nil
        end
      end

      { :total => memTotal,
        :free => memFree,
        :swap_total => swapTotal,
        :swap_free => swapFree,
        :cached => memCached,
        :swap_cached => swapCached}
    end

    #Returns a hash containing all statistics.
    def get()
      {'Processors' => num_processors,
        'Memory' => mem_stats,
        'Load' => load_stats,
        'Disks' => disk_usage, 
        'Users' => Set.new(SystemStats::Utmp::users(@config.utmp_file)).to_a
      }
    end

  end
end

