require 'fileutils'
require 'pacct'

module Bookie::Senders
  ##
  # Returns data from a standalone Linux system
  class Standalone < Bookie::Sender
    ##
    # Yields each job in the log
    def each_job(filename)
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

##
# Originates from the <code>pacct</code> gem
module Pacct
  ##
  # Originates from the <code>pacct</code> gem; reopened here to include Bookie::Sender::ModelHelpers
  class Pacct::Entry
    include Bookie::ModelHelpers
  end
end
