require 'torque_stats'

module Bookie
  module Sender
    class TorqueCluster < Sender
      #Yields each job in the log
      def each_job(date = nil)
        date ||= Date.yesterday
        record = TorqueStats::JobRecord.new(date)
        record.each_job do |job|
          yield job
        end
      end
      
      #To do: remove date parameter? (It's meaningless in the contexts where this would be used.)
      def flush_jobs(date)
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
    end
  end
end