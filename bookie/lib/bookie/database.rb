require 'bookie/config'
require 'bookie/extensions'

require 'active_record'
#TODO: remove when code is updated.
require 'protected_attributes'

require 'bookie/database/job'
require 'bookie/database/job_summary'
require 'bookie/database/user.rb'
require 'bookie/database/system.rb'

module Bookie
  ##
  #Contains database-related code and models
  module Database
    ##
    #A hash mapping memory stat type names to their database codes
    #
    #- <tt>:unknown => 0</tt>
    #- <tt>:avg => 1</tt>
    #- <tt>:max => 2</tt>
    #
      
    ##
    #Database migrations
    module Migration
      class CreateUsers < ActiveRecord::Migration
        def up
          create_table :users do |t|
            t.string :name, :null => false
            t.references :group, :null => false
          end
          change_table :users do |t|
            t.index [:name, :group_id], :unique => true
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
            t.index :name, :unique => true
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
            t.references :system_type, :null => false
            t.datetime :start_time, :null => false
            t.datetime :end_time
            t.integer :cores, :null => false
            t.integer :memory, :null => false, :limit => 8
          end
          change_table :systems do |t|
            t.index [:name, :end_time], :unique => true
            t.index :start_time
            t.index :end_time
            t.index :system_type_id
          end
        end
        
        def down
          drop_table :systems
        end
      end
      
      class CreateSystemTypes < ActiveRecord::Migration
        def up
          create_table :system_types do |t|
            t.string :name, :null => false
            t.integer :memory_stat_type, :limit => 1, :null => false
          end
          change_table :system_types do |t|
            t.index :name, :unique => true
          end
        end
        
        def down
          drop_table :system_types
        end
      end
      
      class CreateJobs < ActiveRecord::Migration
        def up
          create_table :jobs do |t|
            t.references :user, :null => false
            t.references :system, :null => false
            t.string :command_name, :limit => 24, :null => false
            t.datetime :start_time, :null => false
            t.datetime :end_time, :null => false
            t.integer :wall_time, :null => false
            t.integer :cpu_time, :null => false
            t.integer :memory, :null => false
            t.integer :exit_code, :null => false
          end
          #TODO: more indices?
          change_table :jobs do |t|
            t.index :user_id
            t.index :system_id
            t.index :command_name
            t.index :start_time
            t.index :end_time
            t.index :exit_code
          end
        end
      
        def down
          drop_table :jobs
        end
      end
      
      class CreateJobSummaries < ActiveRecord::Migration
        def up
          create_table :job_summaries do |t|
            t.references :user, :null => false
            t.references :system, :null => false
            t.date :date, :null => false
            t.string :command_name, :null => false
            t.integer :cpu_time, :null => false
            t.integer :memory_time, :null => false
          end
          change_table :job_summaries do |t|
            t.index [:date, :user_id, :system_id, :command_name], :unique => true, :name => 'identity'
            t.index :command_name
            t.index :date
          end
        end
        
        def down
         drop_table :job_summaries
        end
      end
      
      class CreateLocks < ActiveRecord::Migration
        def up
          create_table :locks do |t|
            t.string :name
          end
          change_table :locks do |t|
            t.index :name, :unique => true
          end
          
          ['users', 'groups', 'systems', 'system_types', 'job_summaries'].each do |name|
            Lock.create!(:name => name)
          end
        end
          
        def down
          drop_table :locks
        end
      end
    
      class << self;
        ##
        #Brings up all migrations
        def up
          ActiveRecord::Migration.verbose = false
          CreateUsers.new.up
          CreateGroups.new.up
          CreateSystems.new.up
          CreateSystemTypes.new.up
          CreateJobs.new.up
          CreateJobSummaries.new.up
          CreateLocks.new.up
        end
        
        ##
        #Brings down all migrations
        #
        #Warning: this will destroy all data!
        def down
          ActiveRecord::Migration.verbose = false
          CreateUsers.new.down
          CreateGroups.new.down
          CreateSystems.new.down
          CreateSystemTypes.new.down
          CreateJobs.new.down
          CreateJobSummaries.new.down
          CreateLocks.new.down
        end
      end
    end
  end
end


