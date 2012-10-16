require 'bookie'

require 'active_record'

module Bookie
  #Contains ActiveRecord structures for the central database
  module Database
    #ActiveRecord structure for a completed job
    class Job < ActiveRecord::Base
      #To do: integrate with time fields?
      #has_one :date
      has_one :user
      has_one :start_time
      has_one :wall_time
      has_one :cpu_time
      has_one :memory_usage
      has_one :server
    end
    
    #ActiveRecord structure for a user
    clase User < ActiveRecord::Base
      has_one :name
      has_one :group
    end
    
    #ActiveRecord structure for a group
    class Group < ActiveRecord::Base
      has_one :name
      belongs_to_many :users
    end
    
    #ActiveRecord structure for a server
    class Server < ActiveRecord::Base
      has_one :name
      belongs_to_many :jobs
    end
  end
end
