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
      
      def self.by_time_range_inclusive(min, max)
        where('start_time < ? AND end_time > ?', max, min)
      end
      
      #Should probably not be used with queries that filter by start/end time
      def self.summary(min_time = nil, max_time = nil)
        jobs = self
        if min_time
          raise ArgumentError.new('Max time must be specified with min time') unless max_time
          jobs = jobs.by_time_range_inclusive(min_time, max_time)
        end
        num_jobs = 0
        wall_time = 0
        cpu_time = 0
        successful_jobs = 0
        memory_time = 0
        #To consider: job.end_time should be <= Time.now, but it might be good to check for that.
        #Maybe in a database consistency checker tool?
        #What if the system clock is off?
        #Also consider a check for system start times.
        jobs.all.each do |job|
          num_jobs += 1
          job_start_time = job.start_time
          job_end_time = job.end_time
          if min_time
            job_start_time = [job_start_time, min_time].max
            job_end_time = [job_end_time, max_time].min
          end
          clipped_wall_time = job_end_time.to_i - job_start_time.to_i
          wall_time += clipped_wall_time
          if job.wall_time != 0
            cpu_time += job.cpu_time * clipped_wall_time / job.wall_time
            #To consider: what should I do about jobs that only report a max memory value?
            memory_time += job.memory * clipped_wall_time
          end
          successful_jobs += 1 if job.exit_code == 0
        end
      
        return {
          :jobs => num_jobs,
          #To consider: is this field even useful? It's really in job-seconds, not just seconds.
          #What about one in just seconds (that considers gaps in activity)?
          :wall_time => wall_time,
          :cpu_time => cpu_time,
          :memory_time => memory_time,
          :successful =>  if num_jobs == 0 then 0.0 else Float(successful_jobs) / num_jobs end,
        }
      end
      
      #To do: pass summaries in to prevent duplication? Make summary method?
      def load_summary(min_time, max_time)
        s = summary(min_time, max_time)
        s2 = System.summary(min_time, max_time)
        
        cpu_time = s[:cpu_time]
        memory_time = s[:memory_time]
        
        avail_cpu_time = s2[:avail_cpu_time]
        avail_memory_time = s2[:avail_memory_time]
        
        return {
          :used_cpu_time => if avail_cpu_time == 0 then 0.0 else Float(cpu_time) / avail_cpu_time end,
          :used_memory   => if avail_memory_time == 0 then 0.0 else Float(memory_time) / avail_memory_time end,
        }
      end
      
      #To consider: define this in other classes as well?
      def self.each_with_relations
        transaction do
          users = {}
          groups = {}
          systems = {}
          system_types = {}
          all.each do |job|
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
      
      def self.find_or_create!(name, known_groups = nil)
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
      
      def self.find_or_create!(name, group, known_users = nil)
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
    
    MEMORY_STAT_TYPE = {
      :unknown => 0, :avg => 1, :max => 2,
      0 => :unknown, 1 => :avg, 2 => :max}
    
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
      
      def self.summary(min_time = nil, max_time = nil)
        #Sums that are actually returned
        avail_cpu_time = 0
        avail_memory_time = 0
        #Find all the systems within the time range.
        systems = System
        if min_time
          #To do: unit test.
          raise ArgumentError.new('Max time must be specified with min time') unless max_time
          #To consider: optimize as union of queries?
          systems = systems.where(
            'start_time < ? AND (end_time IS NULL OR end_time > ?)',
            max_time,
            min_time)
        end
        n = 0
        systems.all.each do |system|
          n += 1
          system_start_time = system.start_time
          system_end_time = system.end_time
          #Is there a time range constraint?
          if min_time
            system_start_time = [system_start_time, min_time].max
            system_end_time = [system_end_time, max_time].min if system.end_time
            system_end_time ||= max_time
          else
            system_end_time ||= Time.now
          end
          system_wall_time = system_end_time.to_i - system_start_time.to_i
          avail_cpu_time += system.cores * system_wall_time
          avail_memory_time += system.memory * system_wall_time
        end
        
        {
          :avail_cpu_time => avail_cpu_time,
          :avail_memory_time => avail_memory_time,
        }
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
      
      def self.find_or_create!(name, memory_stat_type)
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
        return MEMORY_STAT_TYPE[read_attribute(:memory_stat_type)]
      end
      
      def memory_stat_type=(type)
        type_code = MEMORY_STAT_TYPE[type]
        raise "Unknown memory stat type #{type}" unless type_code
        write_attribute(:memory_stat_type, type_code)
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
          t.references :system_type, :null => false
          t.datetime :start_time, :null => false
          t.datetime :end_time
          t.integer :cores, :null => false
          #To consider: replace with a float? (more compact)
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
