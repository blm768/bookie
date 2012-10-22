require 'bookie'
require 'bookie-linux_client'

require 'date'
require 'pacct'

module Bookie
  module LinuxClient
  #Represents a client that returns data from a standalone Linux server
    class Sender < Bookie::Sender
      #Yields each job in the log
      def each_job(date)
        file = Pacct::File.new('snapshot/pacct')
        file.each_entry do |job|
          yield job
        end
      end
    end
  end
end