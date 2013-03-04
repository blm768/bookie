require 'bookie/config'

require 'active_record'

module Bookie
  #Contains ActiveRecord structures for the central database
  #
  #For a list of fields in the various models, see {Database Tables}[link:rdoc/database_rdoc.html]
  module Database
  
    ##
    #Represents a lock on a table
    #
    #Based on http://kseebaldt.blogspot.com/2007/11/synchronizing-using-active-record.html
    #
    #This should probably not be called within a transaction block; the lock might not be released
    #until the outer transaction completes, and even if it is released before then, there might be
    #concurrency issues.
    class Lock < ActiveRecord::Base
      ##
      #Acquires the lock, runs the given block, and releases the lock when finished
      def synchronize
        transaction do
          #Lock this record to be inaccessible to others until this transaction is completed.
          self.class.lock.find(id)
          yield
        end
      end
      
      @locks = {}
      
      ##
      #Returns a lock by name
      def self.[](name)
        @locks[name.to_sym] ||= find_by_name(name.to_s) or raise "Unable to find lock '#{name}'"
      end
      
      validates_presence_of :name
    end
  
    ##
    #A reported job
    #
    #The various filter methods can be chained to produce more complex queries.
    #
    #===Examples
    #  Bookie::Database::Job.by_user_name('root').by_system_name('localhost').find_each do |job|
    #    puts job.inspect
    #  end
    #
    class Job < ActiveRecord::Base
      belongs_to :user
      belongs_to :system
      
      ##
      #The time at which the job ended
      def end_time
        return start_time + wall_time
      end
      
      ##
      #Filters by user name
      def self.by_user_name(user_name)
        joins(:user).where('users.name = ?', user_name)
      end

      ##
      #Filters by system name
      def self.by_system_name(system_name)
        joins(:system).where('systems.name = ?', system_name)
      end
      
      ##
      #Filters by group name
      def self.by_group_name(group_name)
        group = Group.find_by_name(group_name)
        return joins(:user).where('users.group_id = ?', group.id) if group
        limit(0)
      end
      
      ##
      #Filters by system type
      def self.by_system_type(system_type)
        joins(:system).where('systems.system_type_id = ?', system_type.id)
      end
      
      ##
      #Filters by command name
      def self.by_command_name(c_name)
        where('jobs.command_name = ?', c_name)
      end
      
      ##
      #Filters by a range of start times
      def self.by_start_time_range(time_range)
        where('? <= jobs.start_time AND jobs.start_time < ?', time_range.first, time_range.last)
      end
      
      ##
      #Filters by a range of end times
      def self.by_end_time_range(time_range)
        where('? <= jobs.end_time AND jobs.end_time < ?', time_range.first, time_range.last)
      end
      
      ##
      #Finds all jobs whose running intervals overlap the given time range
      def self.by_time_range_inclusive(time_range)
        where('? <= jobs.end_time AND jobs.start_time < ?', time_range.first, time_range.last)
      end
      
      ##
      #Produces a summary of the jobs in the given time interval
      #
      #Returns a hash with the following fields:
      #- <tt>:jobs</tt>: an array of all jobs in the interval
      #- <tt>:cpu_time</tt>: the total CPU time used
      #- <tt>:memory_time</tt>: the sum of memory * wall_time for all jobs in the interval
      #- <tt>:successful</tt>: the number of jobs that have completed successfully
      #
      #This method should probably not be used with other queries that filter by start/end time.
      def self.summary(time_range = nil)
        time_range = time_range.normalized if time_range
        jobs = self
        jobs = jobs.by_time_range_inclusive(time_range) if time_range
        jobs = jobs.where('jobs.cpu_time > 0').all_with_relations
        cpu_time = 0
        successful_jobs = 0
        memory_time = 0
        #To consider: job.end_time should be <= Time.now, but it might be good to check for that.
        #Maybe in a database consistency checker tool?
        #What if the system clock is off?
        #Also consider a check for system start times.
        jobs.each do |job|
          job_start_time = job.start_time
          job_end_time = job.end_time
          if time_range
            job_start_time = [job_start_time, time_range.first].max
            job_end_time = [job_end_time, time_range.last].min
          end
          clipped_wall_time = job_end_time.to_i - job_start_time.to_i
          if job.wall_time != 0
            cpu_time += job.cpu_time * clipped_wall_time / job.wall_time
            #To consider: what should I do about jobs that only report a max memory value?
            memory_time += job.memory * clipped_wall_time
          end
          #Only count the job as successful if it's actually finished by the end of the summary.
          #To do: unit test this logic.
          if job.exit_code == 0 && (!time_range || job.end_time < time_range.end) then
            successful_jobs += 1
          end
        end
      
        return {
          :jobs => jobs,
          :cpu_time => cpu_time,
          :memory_time => memory_time,
          :successful => successful_jobs,
        }
      end
      
      ##
      #Returns an array of all jobs, pre-loading relations to reduce the need for extra queries
      #
      #Relations are not cached between calls.
      def self.all_with_relations
        jobs = all
        transaction do
          users = {}
          groups = {}
          systems = {}
          system_types = {}
          jobs.each do |job|
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
          end
        end
        
        jobs
      end
      
      before_save do
        write_attribute(:end_time, end_time)
      end
      
      before_update do
        write_attribute(:end_time, end_time)
      end
      
      validates_presence_of :user, :system, :cpu_time,
        :start_time, :wall_time, :memory, :exit_code
       
      validates_each :cpu_time, :wall_time, :memory do |record, attr, value|
        record.errors.add(attr, 'must be a non-negative integer') unless value && value >= 0
      end
      
      validates_each :start_time do |record, attr, value|
        value = value.to_time if value.respond_to?(:to_time)
        record.errors.add(attr, 'must be a time object') unless value.is_a?(Time)
      end
    end
    
    class JobSummary < ActiveRecord::Base
      self.table_name = :job_summaries
    
      belongs_to :user
      belongs_to :system
      
      def self.by_date(date)
        where('job_summaries.date = ?', date)
      end
      
      def self.by_user(user)
        where('job_summaries.user_id = ?', user.id)
      end
      
      def self.by_user_name(name)
        joins(:users).where('users.name = ?', name)
      end
      
      def self.by_system(system)
        where('job_summaries.system_id = ?', system.id)
      end
      
      def self.by_system_name(name)
        joins(:systems).where('systems.name = ?', name)
      end
      
      def self.by_date_range(date_min, date_max)
        where('? <= job_summaries.date AND job_summaries.date < ?', min_date, max_date)
      end
      
      def self.by_command_name(cmd)
        where('job_summaries.command_name = ?', cmd)
      end
      
      #To do: unit test case where known_summaries is nil?
      #Also do the above for other objects' methods!
      def self.find_or_new(date, user_id, system_id, command_name)
        summary = by_date(date).where(:user_id => user_id).where(:system_id => system_id).by_command_name(command_name).first
        summary ||= new(
          :date => date,
          :user_id => user_id,
          :system_id => system_id,
          :command_name => command_name
        )
        summary
      end
      
      def self.summarize(date, jobs = nil)
        jobs ||= Bookie::Database::Job
        time_range = date.to_time ... (date + 1).to_time
        jobs = jobs.by_time_range_inclusive(time_range)
        value_sets = jobs.select('user_id, system_id, command_name').uniq
        value_sets.each do |set|
          summary_jobs = jobs.where(:user_id => set.user_id).where(:system_id => set.system_id).by_command_name(set.command_name)
          summary = summary_jobs.summary(time_range)
          Lock[:job_summaries].synchronize do
            sum = JobSummary.find_or_new(date, set.user_id, set.system_id, set.command_name)
            sum.num_jobs = summary[:jobs].length
            sum.cpu_time = summary[:cpu_time]
            sum.memory_time = summary[:memory_time]
            sum.successful = summary[:successful]
            sum.save!
          end
        end
      end
      
      def self.summary(opts = {})
        jobs = opts[:jobs] || Bookie::Database::Job
        range = opts[:range]
        summaries = self
        unless range
          first_started_system = System.order(:start_time).first
          end_time = nil
          if System.active_systems.any?
            end_time = Time.now
          else
            last_ended_system = System.order('end_time DESC').first
            end_time = last_ended_system.end_time if last_ended_system
          end
          if first_started_system
            range = first_started_system.start_time ... end_time
          else
            #To do: use Dates instead.
            range = Time.at(0) ... Time.at(0)
          end
        end
        range = range.normalized
        
        num_jobs = 0
        cpu_time = 0
        memory_time = 0
        successful = 0
        
        #If there's the potential for partial days at the beginning/end, summarize them:
        unless range.begin.kind_of?(Date) && range.end.kind_of?(Date)
          time_before_min = range.begin
          date_before_max = range.begin.to_date
          date_before_max += 1 unless date_before_max.to_time == time_before_min
          time_before_range = time_before_min ... date_before_max.to_time
          unless time_before_range.empty?
            summary = jobs.summary(time_before_range)
            cpu_time += summary[:cpu_time]
            memory_time += summary[:memory_time]
            successful += summary[:successful]
          end

          date_after_min = range.end.to_date
          time_after_max = range.end
          time_after_range = Range.new(date_after_min.to_time, time_after_max, range.exclude_end?)
          unless time_after_range.empty?
            summary = jobs.summary(time_after_range)
            cpu_time += summary[:cpu_time]
            memory_time += summary[:memory_time]
            successful += summary[:successful]
          end
          
          range = date_before_max .. date_after_min
        end
        
        date = range.begin
        while range.cover?(date) do
          summaries = where('date == ?', date)
          if summaries.empty?
            summarize(date, jobs)
            summaries = where('date == ?', date)
          end
          summaries.find_each do |summary|
            num_jobs += summary.num_jobs
            cpu_time += summary.cpu_time
            memory_time += summary.memory_time
            successful += summary.successful
          end
          date += 1
        end
        
        time_range = Range.new(range.begin.to_time, range.end.to_time, range.exclude_end?)
        jobs = jobs.by_time_range_inclusive(time_range)
        num_jobs = (range && range.empty?) ? 0 : jobs.count
        
        {
          :num_jobs => num_jobs,
          :cpu_time => cpu_time,
          :memory_time => memory_time,
          :successful => successful,
        }
      end
    end
    
    ##
    #A group
    class Group < ActiveRecord::Base
      has_many :users
      
      ##
      #Finds a group by name, creating it if it doesn't exist
      #
      #If <tt>known_groups</tt> is provided, it will be used as a cache to reduce the number of database lookups needed.
      #
      #This uses Lock#synchronize internally, so it probably should not be called within a transaction block.
      def self.find_or_create!(name, known_groups = nil)
        group = known_groups[name] if known_groups
        unless group
          Lock[:groups].synchronize do
            group = find_by_name(name)
            group ||= create!(:name => name)
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
      
      ##
      #Finds a user by name and group, creating it if it doesn't exist
      #
      #If <tt>known_users</tt> is provided, it will be used as a cache to reduce the number of database lookups needed.
      #
      #This uses Lock#synchronize internally, so it probably should not be called within a transaction block.
      def self.find_or_create!(name, group, known_users = nil)
        #Determine if the user/group pair must be added to/retrieved from the database.
        user = known_users[[name, group]] if known_users
        unless user
          Lock[:users].synchronize do
            #Does the user already exist?
            user = Bookie::Database::User.find_by_name_and_group_id(name, group.id)
            user ||= Bookie::Database::User.create!(
              :name => name,
              :group => group
            )
          end
          known_users[[name, group]] = user if known_users
        end
        user
      end
      
      validates_presence_of :group, :name
    end
    
    ##
    #A system on the network
    class System < ActiveRecord::Base
      ##
      #Raised when a system's specifications are different from those of the active system in the database
      SystemConflictError = Class.new(RuntimeError)
      
      has_many :jobs
      belongs_to :system_type
      
      ##
      #Finds all systems that are active (i.e. all systems with NULL values for end_time)
      def self.active_systems
        where('systems.end_time IS NULL')
      end
      
      ##
      #Filters by name
      def self.by_name(name)
        where('systems.name = ?', name)
      end
      
      ##
      #Filters by system type
      def self.by_system_type(sys_type)
        where('systems.system_type_id = ?', sys_type.id)
      end
      
      ##
      #Finds the current system for a given sender and time
      #
      #This method also checks that this system's specifications are the same as those in the database and raises an error if they are different.
      #
      #This uses Lock#synchronize internally, so it probably should not be called within a transaction block.
      #
      def self.find_current(sender, time = nil)
        time ||= Time.now
        config = sender.config
        system = nil
        name = config.hostname
        Lock[:systems].synchronize do
          system = by_name(config.hostname).where('systems.start_time <= :time AND (:time <= systems.end_time OR systems.end_time IS NULL)', :time => time).first
          if system
            mismatch = !(system.cores == config.cores && system.memory == config.memory)
            mismatch ||= sender.system_type != system.system_type
            if mismatch
              raise SystemConflictError.new("The specifications on record for '#{name}' do not match this system's specifications.
Please make sure that all previous systems with this hostname have been marked as decommissioned.")
            end
          else
            raise "There is no system with hostname '#{values[:name]}' in the database at  #{time}."
          end
        end
        system
      end
      
      ##
      #Produces a summary of all the systems for the given time interval
      #
      #Returns a hash with the following fields:
      #- <tt>:avail_cpu_time</tt>: the total CPU time available for the interval
      #- <tt>:avail_memory_time</tt>: the total amount of memory-time available (in kilobyte-seconds)
      #- <tt>:avail_memory_avg</tt>: the average amount of memory available (in kilobytes)
      #
      #To do: make this and other summaries operate differently on inclusive and exclusive ranges.
      #(Current behavior is as if the range were always exclusive.)
      def self.summary(time_range = nil)
        current_time = Time.now
        #Sums that are actually returned
        avail_cpu_time = 0
        avail_memory_time = 0
        #Find all the systems within the time range.
        systems = System
        if time_range
          time_range = time_range.normalized
          #To consider: optimize as union of queries?
          #To do: make consistent with other models' time-range queries.
          systems = systems.where(
            'systems.start_time < ? AND (systems.end_time IS NULL OR systems.end_time > ?)',
            time_range.last,
            time_range.first)
        end
        
        systems.all.each do |system|
          system_start_time = system.start_time
          system_end_time = system.end_time
          #Is there a time range constraint?
          if time_range
            system_start_time = [system_start_time, time_range.first].max
            system_end_time = [system_end_time, time_range.last].min if system.end_time
            system_end_time ||= time_range.last
          else
            system_end_time ||= current_time
          end
          system_wall_time = system_end_time.to_i - system_start_time.to_i
          avail_cpu_time += system.cores * system_wall_time
          avail_memory_time += system.memory * system_wall_time
        end
        
        wall_time_range = 0
        if time_range
          wall_time_range = time_range.last - time_range.first
        else
          first_started_system = systems.order(:start_time).first
          if first_started_system
            #Is there a system still active?
            last_ended_system = systems.where('systems.end_time IS NULL').first
            if last_ended_system
              wall_time_range = current_time.to_i - first_started_system.start_time.to_i
            else
              #No; find the system that was brought down last.
              last_ended_system = systems.order('end_time DESC').first
              wall_time_range = last_ended_system.end_time.to_i - first_started_system.start_time.to_i
            end
          end
        end
          
        {
          :avail_cpu_time => avail_cpu_time,
          :avail_memory_time => avail_memory_time,
          :avail_memory_avg => if wall_time_range == 0 then 0.0 else Float(avail_memory_time) / wall_time_range end,
        }
      end
      
      ##
      #Decommissions the given system, setting its end time to <tt>end_time</tt>
      #
      #This should be called any time a system is brought down or its specifications are changed.
      def decommission(end_time)
        self.end_time = end_time
        self.save!
      end
      
      validates_presence_of :name, :cores, :memory, :system_type, :start_time
      
      validates_each :cores, :memory do |record, attr, value|
        record.errors.add(attr, 'must be a non-negative integer') unless value && value >= 0
      end
      
      validates_each :start_time do |record, attr, value|
        value = value.to_time if value.respond_to?(:to_time)
        record.errors.add(attr, 'must be a time object') unless value.is_a?(Time)
      end
      
      validates_each :end_time do |record, attr, value|
        record.errors.add(attr, 'must be at or after start time') if value && value < record.start_time
      end
    end
    
    ##
    #A hash mapping memory stat type names to their database codes
    #
    #- <tt>:unknown => 0</tt>
    #- <tt>:avg => 1</tt>
    #- <tt>:max => 2</tt>
    #
    MEMORY_STAT_TYPE = {:unknown => 0, :avg => 1, :max => 2}
    
    ##
    #The inverse of MEMORY_STAT_TYPE
    MEMORY_STAT_TYPE_INVERSE = MEMORY_STAT_TYPE.invert
    
    #A system type
    class SystemType < ActiveRecord::Base
      has_many :systems
      
      validates_presence_of :name, :memory_stat_type
      
      ##
      #Finds a system type by name and memory stat type, creating it if it doesn't exist
      #
      #It is an error to attempt to create two types with the same name but different memory stat types.
      #
      #This uses Lock#synchronize internally, so it probably should not be called within a transaction block.
      def self.find_or_create!(name, memory_stat_type)
        sys_type = nil
        Lock[:system_types].synchronize do
          sys_type = SystemType.find_by_name(name)
          if sys_type
            unless sys_type.memory_stat_type == memory_stat_type
              type_code = MEMORY_STAT_TYPE[memory_stat_type]
              if type_code == nil
                raise "Unrecognized memory stat type '#{memory_stat_type}'"
              else
                raise "The recorded memory stat type for system type '#{name}' does not match the required type of #{type_code}"
              end
            end
          else
            sys_type = create!(
              :name => name,
              :memory_stat_type => memory_stat_type
            )
          end
        end
        sys_type
      end
      
      ##
      #Returns the memory stat type as a symbol
      #
      #See Bookie::Database::MEMORY_STAT_TYPE for possible values.
      #
      #Based on http://www.kensodev.com/2012/05/08/the-simplest-enum-you-will-ever-find-for-your-activerecord-models/
      def memory_stat_type
        type_code = read_attribute(:memory_stat_type)
        raise 'Memory stat type must not be nil' if type_code == nil
        type = MEMORY_STAT_TYPE_INVERSE[type_code]
        raise "Unrecognized memory stat type code #{type_code}" unless type
        type
      end
      
      ##
      #Sets the memory stat type
      #
      #<tt>type</tt> should be a symbol.
      def memory_stat_type=(type)
        raise 'Memory stat type must not be nil' if type == nil
        type_code = MEMORY_STAT_TYPE[type]
        raise "Unrecognized memory stat type '#{type}'" unless type_code
        write_attribute(:memory_stat_type, type_code)
      end
    end
  
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
            t.string :command_name, :limit => 24
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
            t.index :command_name
            t.index :start_time
            t.index :end_time
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
            t.integer :num_jobs, :null => false
            t.integer :cpu_time, :null => false
            t.integer :memory_time, :null => false
            t.integer :successful, :null => false
          end
          change_table :job_summaries do |t|
            #To do: reorder for optimum efficiency?
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

class Range
  def normalized
    return first ... first if last < first
    self
  end
  
  def empty?
    (self.end < self.begin) || (exclude_end? && (self.begin == self.end))
  end
  
  def intersection(other)
    self_n = self.normalized
    other = other.normalized
    
    new_begin, new_end, exclude_end = nil
    
    if self_n.cover?(other.begin)
      new_first = other.begin
    elsif other.cover?(self_n.begin)
      new_first = self_n.begin
    end
    
    return self_n.begin ... self_n.begin unless new_first
    
    if self_n.cover?(other.end)
      unless other.exclude_end? && other.end == self_n.begin
        new_end = other.end
        exclude_end = other.exclude_end?
      end
    elsif other.cover?(self_n.end)
      unless self_n.exclude_end? && self_n.end == other.begin
        new_end = self_n.end
        exclude_end = self_n.exclude_end?
      end
    end
    
    #If we still haven't found new_end, try one more case:
    unless new_end
      if self_n.end == other.end
        #We'll only get here if both ranges exclude their ends and have the same end.
        new_end = self_n.end
        exclude_end = true
      end
    end
    
    return self_n.begin ... self_n.begin unless new_end

    Range.new(new_begin, new_end, exclude_end)
  end
end
