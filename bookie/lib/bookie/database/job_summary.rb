require 'active_record'
require 'protected_attributes'

require 'bookie/database/job'
require 'bookie/database/system'
require 'bookie/database/user'

module Bookie
  module Database
    ##
    #A cached summary of Jobs in the database
    #
    #Most summary operations should be performed through this class to improve efficiency.
    class JobSummary < ActiveRecord::Base
      self.table_name = :job_summaries
    
      belongs_to :user
      belongs_to :system

      attr_accessible :date, :user, :user_id, :system, :system_id, :command_name, :cpu_time, :memory_time
      
      ##
      #Filters by date
      def self.by_date(date)
        where('job_summaries.date = ?', date)
      end

      ##
      #Filters by a date range
      def self.by_date_range(range)
        range = range.normalized
        if range.exclude_end?
          where('? <= job_summaries.date AND job_summaries.date < ?', range.begin, range.end)
        else
          where('? <= job_summaries.date AND job_summaries.date <= ?', range.begin, range.end)
        end
      end
      
      ##
      #Filters by user
      def self.by_user(user)
        where('job_summaries.user_id = ?', user.id)
      end
      
      ##
      #Filters by user name
      def self.by_user_name(name)
        joins(:user).where('users.name = ?', name)
      end
      
      ##
      #Filters by group
      def self.by_group(group)
        joins(:user).where('users.group_id = ?', group.id)
      end
      
      ##
      #Filters by group name
      def self.by_group_name(name)
        group = Group.where(:name => name).first
        if group
          by_group(group)
        else
          self.none
        end
      end
      
      ##
      #Filters by system
      def self.by_system(system)
        where('job_summaries.system_id = ?', system.id)
      end
      
      ##
      #Filters by system name
      def self.by_system_name(name)
        joins(:system).where('systems.name = ?', name)
      end
      
      ##
      #Filters by system type
      def self.by_system_type(type)
        joins(:system).where('systems.system_type_id = ?', type.id)
      end
      
      ##
      #Filters by command name
      def self.by_command_name(cmd)
        where('job_summaries.command_name = ?', cmd)
      end
      
      ##
      #Create cached summaries for the given date
      #
      #The date is interpreted as being in UTC.
      #
      #If there is nothing to summarize, a dummy summary will be created.
      #
      #Uses Lock::synchronize internally; should not be used in transaction blocks
      #
      #TODO: what if this is called while jobs are being sent?
      def self.summarize(date)
        jobs = Job
        unscoped = self.unscoped
        time_min = date.to_utc_time 
        time_range = time_min ... time_min + 1.days
        day_jobs = jobs.by_time_range(time_range)

        #Find the unique combinations of values for some of the jobs' attributes.
        value_sets = day_jobs.select('user_id, system_id, command_name').uniq
        if value_sets.empty?
          #There are no jobs, so create a dummy summary.
          user = User.select(:id).first
          system = System.select(:id).first
          #If there are no users or no systems, we can't create the dummy summary, so just return.
          #To consider: figure out how to create the dummy summary anyway?
          return unless user && system
          #Create a dummy summary so summary() doesn't keep trying to create one.
          Lock[:job_summaries].synchronize do
            sum = unscoped.find_or_initialize_by(
              :date => date,
              :user_id => user.id,
              :system_id => system.id,
              :command_name => ''
            )
            sum.cpu_time = 0
            sum.memory_time = 0
            sum.save!
          end
        else
          value_sets.each do |set|
            summary_jobs = jobs.where(
              :user_id => set.user_id,
              :system_id => set.system_id,
              :command_name => set.command_name
            )
            summary = summary_jobs.summary(time_range)
            Lock[:job_summaries].synchronize do
              sum = unscoped.find_or_initialize_by(
                :date => date,
                :user_id => set.user_id,
                :system_id => set.system_id,
                :command_name => set.command_name
              )
              sum.cpu_time = summary[:cpu_time]
              sum.memory_time = summary[:memory_time]
              sum.save!
            end
          end
        end
      end
      
      ##
      #Returns a summary of jobs in the database
      #
      #The following options are supported:
      #- [<tt>:range</tt>] restricts the summary to a specific time interval (specified as a Range of Time objects)
      #- [<tt>:jobs</tt>] the jobs on which the summary should operate
      #
      #Internally, this may call JobSummary::summarize, which uses Lock#synchronize, so this should not be used inside a transaction block.
      #
      #When filtering, the same filters must be applied to both the Jobs and the JobSummaries. For example:
      # jobs = Bookie::Database::Job.by_user_name('root')
      # summaries = Bookie::Database::Job.by_user_name('root')
      # puts summaries.summary(:jobs => jobs)
      def self.summary(opts = {})
        jobs = opts[:jobs] || Job
        time_range = opts[:range]

        unless time_range
          #TODO: put this in its own method.
          start_time = jobs.minimum(:start_time)
          end_time = jobs.maximum(:end_time)
          if start_time && end_time
            time_range = start_time .. end_time
          else
            time_range = Time.new ... Time.new
          end
        end

        time_range = time_range.normalized
        
        date_begin = time_range.begin.utc.to_date
        rounded_date_begin = false
        #Round date_begin up.
        if date_begin.to_utc_time < time_range.begin
          date_begin += 1
          rounded_date_begin = true
        end
        date_end = time_range.end.utc.to_date

        #Is the interval large enough to cover any cached summaries?
        if date_begin >= date_end
          #Nope; just return a regular summary.
          return jobs.summary(time_range)
        end

        jobs_in_range = jobs.by_time_range(time_range)
        num_jobs = jobs_in_range.count
        successful = jobs_in_range.where('jobs.exit_code = 0').count
        cpu_time = 0
        memory_time = 0
        
        #TODO: check if num_jobs is zero so we can skip all this?
        if rounded_date_begin
          #We need to get a summary for the chunk up to the first whole day.
          summary = jobs.summary(time_range.begin ... date_begin.to_utc_time)
          cpu_time += summary[:cpu_time]
          memory_time += summary[:memory_time]
        end

        date_end_time = date_end.to_utc_time
        if date_end_time < time_range.end
          #We need to get a summary for the chunk after the last whole day.
          range = Range.new(date_end_time, time_range.end, time_range.exclude_end?)
          summary = jobs.summary(range)
          cpu_time += summary[:cpu_time]
          memory_time += summary[:memory_time]
        end

        date_range = date_begin ... date_end
        
        #Now we can process the cached summaries.
        unscoped = self.unscoped
        summaries = by_date_range(date_range).order(:date).to_a
        index = 0
        date_range.each do |date|
          new_index = index
          summary = summaries[new_index]
          while summary && summary.date == date do
            cpu_time += summary.cpu_time
            memory_time += summary.memory_time
            new_index += 1
            summary = summaries[new_index]
          end
          #Did we actually process any summaries?
          #If not, have _any_ summaries been created for this day?
          if new_index == index && !(unscoped.by_date(date).any?)
            #Nope. Create the summaries.
            unscoped.summarize(date)
            #To consider: optimize out the query?
            by_date(date).each do |sum|
              cpu_time += sum.cpu_time
              memory_time += sum.memory_time
            end
          end
          index = new_index
        end
        
        {
          :num_jobs => num_jobs,
          :successful => successful,
          :cpu_time => cpu_time,
          :memory_time => memory_time,
        }
      end
      
      validates_presence_of :user_id, :system_id, :date, :cpu_time, :memory_time
      
      validates_each :command_name do |record, attr, value|
        record.errors.add(attr, 'must not be nil') if value == nil
      end
      
      validates_each :cpu_time, :memory_time do |record, attr, value|
        record.errors.add(attr, 'must be a non-negative integer') unless value && value >= 0
      end
    end
  end
end
