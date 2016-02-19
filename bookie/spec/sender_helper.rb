module SenderHelpers
  class JobStub
    attr_accessor :user_id, :user_name
    attr_accessor :command_name
    attr_accessor :start_time, :wall_time
    attr_accessor :cpu_time, :memory
    attr_accessor :exit_code

    include Bookie::ModelHelpers

    def self.from_job(job)
      stub = self.new
      stub.user_id = job.user.id
      stub.user_name = job.user.name
      stub.command_name = job.command_name
      stub.start_time = job.start_time
      stub.wall_time = job.wall_time
      stub.cpu_time = job.cpu_time
      stub.memory = job.memory
      stub.exit_code = job.exit_code
      stub
    end

    def self.from_hash(hash)
      stub = self.new
      hash.each_pair do |key, value|
        stub.send("#{key}=", value)
      end
      stub
    end
  end

  module DummySender
    def each_job(filename)
      20.times do |i|
        #TODO: add some variety...
        yield JobStub.from_hash(command_name: 'vi', user_id: 2, start_time: Time.at(1349679573) + i.minutes,
            exit_code: 0, cpu_time: 63, memory: 139776, wall_time: 67)
      end
    end

    def system_type_name
      'Dummy'
    end

    def memory_stat_type
      :unknown
    end
  end

  #TODO: make this useful.
  module ShortDummySender
    include DummySender

    def each_job(filename)
      yield JobStub.from_hash(command_name: 'vi', user_id: 1, start_time: Time.at(1349679572),
          exit_code: 0, cpu_time: 63, memory: 139776, wall_time: 67)
    end
  end

  module EmptyDummySender
    include DummySender

    def each_job(filename)
      return
    end
  end

  #Allows the system type "dummy" in the config
  def new_dummy_sender(config, dummy_module = DummySender)
    Bookie::Sender.any_instance.stubs(:require).with('bookie/senders/dummy').returns(true)
    Bookie::Senders.stubs(:const_get).with('Dummy').returns(dummy_module)
    begin
      sender = Bookie::Sender.new(config)
    ensure
      Bookie::Sender.any_instance.unstub(:require)
      Bookie::Senders.unstub(:const_get)
    end
    sender
  end
end
