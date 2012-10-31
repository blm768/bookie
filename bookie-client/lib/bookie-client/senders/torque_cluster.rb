module Bookie
  module Sender
    class TorqueCluster < Sender
      #Yields each job in the log
      def each_job(date = nil)
        date ||= Date.today
        record = TorqueStats::JobRecord.new(date)
        record.each_job do |job|
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