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
      has_one :server
    end
    
    #ActiveRecord structure for a user
    class User < ActiveRecord::Base
      has_one :group
    end
    
    #ActiveRecord structure for a group
    class Group < ActiveRecord::Base
      belongs_to :user
    end
    
    #ActiveRecord structure for a server
    class Server < ActiveRecord::Base
      belongs_to :job
      
      validates_presence_of :name
    end
  end
end
