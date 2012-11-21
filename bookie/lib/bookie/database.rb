require 'bookie'

require 'active_record'

module Bookie
  #Contains ActiveRecord structures for the central database
  module Database
    #ActiveRecord structure for a completed job
    class Job < ActiveRecord::Base
      belongs_to :user
      belongs_to :system
      
      def end_time
        return start_time + wall_time
      end
      
      def self.by_user_name(user_name)
        joins(:user).where('users.name = ?', user_name)
      end

      def self.by_system_name(system_name)
        joins(:system).where('systems.name = ?', system_name)
      end
      
      def self.by_group_name(group_name)
        group = Group.find_by_name(group_name)
        return joins(:user).where('group_id = ?', group.id) if group
        limit(0)
      end
      
      def self.by_system_type(system_type)
        joins(:system).where('system_type_id = ?', system_type.id)
      end
      
      def self.by_start_time_range(start_min, start_max)
        where('? <= start_time AND start_time < ?', start_min, start_max)
      end
      
      def self.by_end_time_range(end_min, end_max)
        where('? <= end_time AND end_time < ?', end_min, end_max)
      end
      
      #Should probably not be used with by_(start/end)_time_range
      def self.summary(start_time = nil, end_time = nil)
        jobs = self
        if start_time
          raise ArgumentError.new('End time must be specified with start time') unless end_time
          jobs = where('start_time < ? AND end_time > ?', end_time, start_time)
        end
        num_jobs = 0
        wall_time = 0
        cpu_time = 0
        successful_jobs = 0
        jobs.find_each do |job|
          num_jobs += 1
          job_start_time = job.start_time
          job_end_time = job.end_time
          if start_time
            job_start_time = [job_start_time, start_time].max
            job_end_time = [job_end_time, end_time].min
          end
          clipped_wall_time = job_end_time.to_i - job_start_time.to_i
          wall_time += clipped_wall_time
          cpu_time += Integer(job.cpu_time * clipped_wall_time / job.wall_time)
          successful_jobs += 1 if job.exit_code == 0
        end
        
        total_cpu_time = 0
        #Find all the systems within the time range.
        systems = Bookie::Database::System
        if start_time
          #To do: optimize as union of queries?
          systems = systems.where(
            'start_time < ? AND (end_time IS NULL OR end_time > ?)',
            end_time,
            start_time)
        end
        systems.find_each do |system|
          system_start_time = system.start_time
          system_end_time = system.end_time
          #Is there a date range constraint?
          if start_time
            system_start_time = [system_start_time, start_time].max
            system_end_time = [system_end_time, end_time].min if system.end_time
            system_end_time ||= end_time
          else
            system_end_time ||= Time.now
          end
          total_cpu_time += system.cores * (system_end_time.to_i - system_start_time.to_i)
        end
      
        return {
          :jobs => num_jobs,
          :wall_time => wall_time,
          :cpu_time => cpu_time,
          :successful =>  if num_jobs == 0 then 0.0 else Float(successful_jobs) / num_jobs end,
          :total_cpu_time => total_cpu_time,
          :used_cpu_time => if total_cpu_time == 0 then 0.0 else cpu_time / total_cpu_time end,
        }
      end
      
      #To do: define this in other classes as well?
      def self.each_with_relations
        transaction do
          users = {}
          groups = {}
          systems = {}
          system_types = {}
          find_each do |job|
            system = systems[job.system_id]
            if system
              job.system = system
            else
              system = job.system
              systems[system.id] = system
            end
            system_type = system_types[system.system_type_id]
            if system_type
              system.system_type = system_type
            else
              system_type = system.system_type
              system_types[system_type.id] = system_type
            end
            user = users[job.user_id]
            if user
              job.user = user
            else
              user = job.user
              users[user.id] = user
            end
            group = groups[user.group_id]
            if group
              user.group = group
            else
              group = user.group
              groups[group.id] = group
            end
            yield job
          end
        end
      end
      
      before_save do
        write_attribute(:end_time, end_time)
      end
      
      before_update do
        write_attribute(:end_time, end_time)
      end
      
      validates_presence_of :user, :system, :cpu_time,
        :start_time, :wall_time, :memory, :exit_code
    end
    
    #ActiveRecord structure for a group
    class Group < ActiveRecord::Base
      has_many :users
      
      def self.find_or_create(name, known_groups = nil)
        group = known_groups[name] if known_groups
        unless group
          transaction do
            group = Bookie::Database::Group.lock.find_by_name(name)
            group ||= Bookie::Database::Group.create!(:name => name)
          end
          known_groups[name] = group if known_groups
        end
        group
      end
      
      validates_presence_of :name
    end
    
    #ActiveRecord structure for a user
    class User < ActiveRecord::Base
      belongs_to :group
      
      def self.find_or_create(name, group, known_users = nil)
        #Determine if the user/group pair must be added to/retrieved from the database.
        user = known_users[[name, group]] if known_users
        unless user
          transaction do
            #Does the user already exist?
            user = Bookie::Database::User.lock.find_by_name_and_group_id(name, group.id)
            user ||= Bookie::Database::User.create!(
              :name => name,
              :group => group)
          end
          known_users[[name, group]] = user if known_users
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
      
      def self.active_systems
        where('end_time IS NULL')
      end
      
      def self.by_name(name)
        where('name = ?', name)
      end
      
      def decommission(end_time)
        self.end_time = end_time
        self.save!
      end
      
      validates_presence_of :name, :cores, :memory, :system_type, :start_time
    end
    
    #ActiveRecord structure for a system type
    class SystemType < ActiveRecord::Base
      has_many :systems
      
      validates_presence_of :name, :memory_stat_type
      
      def self.find_or_create(name, memory_stat_type)
        sys_type = nil
        #To do: better assurance of correctness under concurrency
        #To do: handle name conflicts?
        transaction do
          sys_type = SystemType.lock.find_by_name(name)
          sys_type ||= create!(
            :name => name,
            :memory_stat_type => memory_stat_type)
        end
        sys_type
      end
      
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
          t.integer :memory, :null => false
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
