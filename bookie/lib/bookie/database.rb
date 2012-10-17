require 'bookie'

require 'active_record'

module Bookie
  #Contains ActiveRecord structures for the central database
  module Database
    #ActiveRecord structure for a completed job
    class Job < ActiveRecord::Base
      #To do: integrate with time fields?
      #has_one :date
      belongs_to :user
      belongs_to :server
      
      validates_presence_of :user, :server, :cpu_time, :start_time, :wall_time, :memory_usage
    end
    
    #ActiveRecord structure for a user
    class User < ActiveRecord::Base
      belongs_to :group
      
      validates_presence_of :group, :name
    end
    
    #ActiveRecord structure for a group
    class Group < ActiveRecord::Base
      has_many :users
      
      validates_presence_of :name
    end
    
    #ActiveRecord structure for a server
    class Server < ActiveRecord::Base
      has_many :jobs
      
      validates_presence_of :name
    end
  end
end
