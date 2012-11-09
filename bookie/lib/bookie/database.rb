require 'bookie'

require 'active_record'

module Bookie
  #Contains ActiveRecord structures for the central database
  module Database
    #ActiveRecord structure for a completed job
    class Job < ActiveRecord::Base
      belongs_to :user
      belongs_to :system
      
      scope :by_user_name, lambda { |user_name|
        joins(:user).where('users.name = ?', user_name)
      }

      scope :by_system_name, lambda { |system_name|
        joins(:system).where('systems.name = ?', system_name)
      }
      
      scope :by_group_name, lambda { |group_name|
        group = Group.find_by_name(group_name).first
        return joins(:user).where('group_id = ?', group.id) if group
        limit(0)
      }
      
      scope :by_system_type, lambda { |system_type|
        joins(:system).where('system_type_id = ?', system_type.id)
      }
      
      scope :by_start_time_range, lambda { |start_min, start_max|
        where('? <= start_time AND start_time < ?', start_min, start_max)
      }
      
      scope :by_end_time_range, lambda { |end_min, end_max|
        where('? <= end_time AND end_time < ?', end_min, end_max)
      }
      
      #To do: rename to likely_duplicates?
      def duplicates
        Job.joins(:system).where(
              'systems.name = ? AND job_id = ? AND array_id = ? AND jobs.start_time = ?',
              system.name,
              id,
              array_id,
              start_time)
      end
      
      validates_presence_of :job_id, :array_id, :user, :system, :cpu_time,
        :start_time, :end_time, :wall_time, :memory, :exit_code
    end
    
    #ActiveRecord structure for a group
    class Group < ActiveRecord::Base
      has_many :users
      
      def self.find_or_create(name, known_groups = nil)
        group = known_groups[name] if known_groups
        unless group
          group = Bookie::Database::Group.find_by_name(name)
          group ||= Bookie::Database::Group.create!(:name => name)
          known_groups[name] = group if known_groups
        end
        group
      end
      
      validates_presence_of :name
    end
    
    #ActiveRecord structure for a user
    class User < ActiveRecord::Base
      belongs_to :group
      
      def self.find_or_create(name, group_name, known_users = nil, known_groups = nil)
        #Determine if the user/group pair must be added to/retrieved from the database.
        user = known_users[[name, group_name]] if known_users
        unless user
          #Does the group exist?
          group = Group.find_or_create(group_name, known_groups)
          #Does the user already exist?
          user = Bookie::Database::User.find_by_name_and_group_id(name, group.id)
          user ||= Bookie::Database::User.create!(
            :name => name,
            :group => group)
          known_users[[name, group_name]] = user
        end
        user
      end
      
      validates_presence_of :group, :name
    end
    
    MEMORY_STAT_TYPE = {:unknown => 0, :avg => 1, :max => 2}
    
    #ActiveRecord structure for a network system
    class System < ActiveRecord::Base
      has_many :jobs
      belongs_to :system_type
      
      def self.find_by_specs(name, system_type, cores)
         find_by_name_and_system_type_id_and_cores(name, system_type.id, cores)
      end
      
      def self.conflicting_systems(name)
        where('name = ? AND end_time IS NULL', name)
      end
      
      validates_presence_of :name, :cores, :system_type, :start_time
    end
    
    #ActiveRecord structure for a system type
    class SystemType < ActiveRecord::Base
      has_many :systems
      
      validates_presence_of :name, :memory_stat_type
      
      #Based on http://www.kensodev.com/2012/05/08/the-simplest-enum-you-will-ever-find-for-your-activerecord-models/
      def memory_stat_type
        #To do: optimize?
        return MEMORY_STAT_TYPE.key(read_attribute(:memory_stat_type))
      end
      
      def memory_stat_type=(type)
        #To do: check for invalid types?
        write_attribute(:memory_stat_type, MEMORY_STAT_TYPE[type])
      end
    end
  
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
          #A 1-byte integer (hopefully)
          t.references :system_type, :null => false
          t.datetime :start_time, :null => false
          t.datetime :end_time
          #To do: determine correct type sizes.
          t.integer :cores, :null => false
        end
        change_table :systems do |t|
          t.index [:name, :system_type_id, :cores, :start_time], :unique => true, :name => 'identity'
          #To do: include name here?
          t.index [:end_time]
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
          t.index [:job_id, :array_id]
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
        CreateSystemTypes.new.up
        CreateJobs.new.up
      end
      
      def drop_tables
        CreateUsers.new.down
        CreateGroups.new.down
        CreateSystems.new.down
        CreateSystemTypes.new.down
        CreateJobs.new.down
      end
    end
  end
end
