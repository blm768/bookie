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
      belongs_to :system
      
      validates_presence_of :job_id, :array_id, :user, :system, :cpu_time,
        :start_time, :end_time, :wall_time, :memory, :exit_code
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
    
    SYSTEM_TYPE = {:standalone => 0, :torque_cluster => 1}
    SYSTEM_TYPE_NAMES = {:standalone => "Standalone", :torque_cluster => "TORQUE cluster"}
    
    #ActiveRecord structure for a network system
    class System < ActiveRecord::Base
      has_many :jobs
      
      #To do: add cores, memory
      validates_presence_of :name, :cores, :system_type, :start_time
      
      #Based on http://www.kensodev.com/2012/05/08/the-simplest-enum-you-will-ever-find-for-your-activerecord-models/
      def system_type
        #To do: optimize?
        return SYSTEM_TYPE.key(read_attribute(:system_type))
      end
      
      def system_type=(type)
        write_attribute(:system_type, SYSTEM_TYPE[type])
      end
    end
  
    class CreateUsers < ActiveRecord::Migration
      def up
        create_table :users do |t|
          t.string :name, :null => false
          t.references :group, :null => false
        end
        change_table :users do |t|
          t.index :name
          #To do: remove?
          t.index :group_id
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
        change_table :groups do |t|
          t.index :name
        end
      end
      
      def down
        drop_table :groups
      end
    end
    
    class CreateSystems < ActiveRecord::Migration
      def up
        create_table :systems do |t|
          t.string :name, :null => false
          #A 1-byte integer (hopefully)
          t.integer :system_type, :limit => 1, :null => false
          t.datetime :start_time, :null => false
          t.datetime :end_time
          #To do: determine correct type sizes.
          t.integer :cores, :null => false
          #To do: make NOT NULL
          t.integer :memory
        end
        change_table :systems do |t|
          t.index :name
          t.index :system_type
          t.index :cores
          t.index :memory
        end
      end
      
      def down
        drop_table :systems
      end
    end
    
    class CreateJobs < ActiveRecord::Migration
      def up
        create_table :jobs do |t|
          #To do: determine correct type sizes.
          t.integer :job_id, :null => false
          t.integer :array_id, :null => false
          t.references :user, :null => false
          t.references :system, :null => false
          t.datetime :start_time, :null => false
          t.datetime :end_time, :null => false
          t.integer :wall_time, :null => false
          t.integer :cpu_time, :null => false
          t.integer :memory, :null => false
          t.integer :exit_code, :null => false
        end
        change_table :jobs do |t|
          t.index :job_id
          t.index :array_id
          t.index :user_id
          t.index :system_id
          t.index :start_time
          t.index :end_time
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
        CreateSystems.new.up
        CreateJobs.new.up
      end
      
      def drop_tables
        CreateUsers.new.down
        CreateGroups.new.down
        CreateSystems.new.down
        CreateJobs.new.down
      end
    end
  end
end
