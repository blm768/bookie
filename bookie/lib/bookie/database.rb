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
      
      validates_presence_of :job_id_hash, :user, :server, :cpu_time, :start_time, :end_time, :wall_time, :memory, :exit_code
    end
    
    #ActiveRecord structure for a group
    class Group < ActiveRecord::Base
      has_many :users
      
      validates_presence_of :name
    end
    
    #ActiveRecord structure for a user
    class User < ActiveRecord::Base
      belongs_to :group
      
      validates_presence_of :group, :name
    end
    
    SERVER_TYPE = {:standalone => 0, :torque_cluster => 1}
    SERVER_TYPE_NAMES = {:standalone => "Standalone", :torque_cluster => "TORQUE cluster"}
    
    #ActiveRecord structure for a server
    class Server < ActiveRecord::Base
      has_many :jobs
      
      validates_presence_of :name, :server_type
      
      #Based on http://www.kensodev.com/2012/05/08/the-simplest-enum-you-will-ever-find-for-your-activerecord-models/
      def server_type
        return SERVER_TYPE.key(read_attribute(:server_type))
      end
      
      def server_type=(type)
        write_attribute(:server_type, SERVER_TYPE[type])
      end
    end
  
    class CreateUsers < ActiveRecord::Migration
      def up
        create_table :users do |t|
          t.string :name, :null => false
          t.references :group, :null => false
        end
      end
      
      def down
        drop_table :users
      end
    end
    
    class CreateGroups < ActiveRecord::Migration
      def up
        create_table :groups do |t|
          t.string :name, :null => false
        end
      end
      
      def down
        drop_table :groups
      end
    end
    
    class CreateServers < ActiveRecord::Migration
      def up
        create_table :servers do |t|
          t.string :name, :null => false
          #A 1-byte integer (hopefully)
          t.integer :server_type, :limit => 1, :null => false
        end
      end
      
      def down
        drop_table :servers
      end
    end
    
    class CreateJobs < ActiveRecord::Migration
      def up
        create_table :jobs do |t|
          t.integer :job_id_hash, :null=>false
          t.references :user, :null => false
          t.references :server, :null => false
          t.datetime :start_time, :null => false
          t.datetime :end_time, :null => false
          t.integer :wall_time, :null => false
          t.integer :cpu_time, :null => false
          t.integer :memory, :null => false
          t.integer :exit_code, :null => false
        end
      end
    
      def down
        drop_table :jobs
      end
    end
    
    class << self;
      def create_tables
        CreateUsers.new.up
        CreateGroups.new.up
        CreateServers.new.up
        CreateJobs.new.up
      end
      
      def drop_tables
        CreateUsers.new.down
        CreateGroups.new.down
        CreateServers.new.down
        CreateJobs.new.down
      end
    end
  end
end
