require 'torque_stats'

module Bookie
  module Sender
    module TorqueCluster
      #Yields each job in the log
      def each_job(filename = nil)
        filename ||= filename_for_date(Date.yesterday)
        record = TorqueStats::JobRecord.new(filename)
        record.each_job do |job|
          yield job
        end
      end
      
      #To do: remove filename parameter? (It's meaningless in the contexts where this would be used.)
      def flush_jobs(filename)
        each_job(Date.today) do |job|
          yield job
        end
      end
      
      def system_type_name
        return "TORQUE cluster"
      end
      
      def memory_stat_type
        return :max
      end
      
      def filename_for_date(date)
        TorqueStats::filename_for_date(date)
      end
    end
  end
end