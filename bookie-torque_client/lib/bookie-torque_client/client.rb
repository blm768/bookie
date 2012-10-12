require 'bookie'
require 'bookie-torque_client'

require 'date'
require 'torque_stats'

module Bookie
  module TorqueClient
  #Represents a client that returns data from a TORQUE cluster
    class Client < Bookie::Client
      def send_data(date = Date.yesterday)
        record = TorqueStats::JobRecord.new(date)
        record.each_job do |job|
          puts filter_job(job)
        end
      end
    end
  end
end