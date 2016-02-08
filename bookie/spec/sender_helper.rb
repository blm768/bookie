module SenderHelpers
  module DummySender
    def each_job(filename)
      20.times do |i|
        #TODO: add some variety...
        yield JobStub.from_hash(user_id: 2, start_time: Time.at(1349679573) + i.minutes,
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
      yield JobStub.from_hash(user_id: 1, start_time: Time.at(1349679572),
          exit_code: 0, cpu_time: 63, memory: 139776, wall_time: 67)
    end
  end

  #Allows the system type "dummy" in the config
  def new_dummy_sender(config)
    Bookie::Sender.any_instance.stubs(:require).with('bookie/senders/dummy').returns(true)
    Bookie::Senders.stubs(:const_get).with('Dummy').returns(DummySender)
    begin
      sender = Bookie::Sender.new(config)
    ensure
      Bookie::Sender.any_instance.unstub(:require)
      Bookie::Senders.unstub(:const_get)
    end
    sender
  end
end
