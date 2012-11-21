require 'torque_stats'

module Bookie
  module Sender
    module TorqueCluster
      #Yields each job in the log
      def each_job(filename)
        record = TorqueStats::JobLog.new(filename)
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

module TorqueStats
  class Job
    include Bookie::Sender::ModelHelpers
  end
end