module FormatterHelpers
  class IOMock
    def initialize
      @buf = ""
    end

    def puts(str)
      @buf << str.to_s
      @buf << "\n"
    end

    def write(str)
      @buf << str.to_s
    end

    def printf(format, *args)
      @buf << sprintf(format, *args)
    end

    def buf
      @buf
    end
  end

  JOB_SUMMARY = {
    num_jobs: 40,
    successful: 20,
    cpu_time: 1.hours + 6.minutes + 40.seconds,
    memory_time: 28800000
  }

  JOB_SUMMARY_EMPTY = {
    num_jobs: 0,
    successful: 0,
    cpu_time: 0,
    memory_time: 0
  }

  SYSTEM_CAPACITY_SUMMARY = {
    avail_cpu_time: 5.days + 20.hours,
    avail_memory_time: 1750000 * 40.hours,
    avail_memory_avg: 1750000
  }

  SYSTEM_CAPACITY_SUMMARY_EMPTY = {
    avail_cpu_time: 0,
    avail_memory_time: 0,
    avail_memory_avg: 0
  }
end
