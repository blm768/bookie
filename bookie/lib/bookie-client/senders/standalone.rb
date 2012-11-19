require 'fileutils'
require 'pacct'

module Bookie
  module Sender
    #Represents a client that returns data from a standalone Linux system
    module Standalone
      #Yields each job in the log
      def each_job(filename = nil)
        file = Pacct::Log.new(filename)
        file.each_entry do |job|
          yield job
        end
      end
      
      def system_type_name
        "Standalone"
      end
      
      def memory_stat_type
        :avg
      end
      
    end
  end
end

module Pacct
  class Entry
    include Bookie::Sender::ModelHelpers
    
    def job_id
      process_id
    end
    
    def array_id
      0
    end
  end
end