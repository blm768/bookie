require 'bookie/database'

module Bookie::Database
  ##
  #A cached summary of Jobs in the database
  #
  #Most summary operations should be performed through this class to improve efficiency.
  class JobSummary < Model
    self.table_name = :job_summaries

    belongs_to :user
    belongs_to :system

    ##
    #Create cached summaries for the given date
    #
    #The date is interpreted as being in UTC.
    #
    #If there is nothing to summarize, a dummy summary will be created.
    def self.summarize(date)
      jobs = Job
      unscoped = self.unscoped
      time_min = date.to_utc_time
      time_max = time_min + 1.days
      day_jobs = jobs.by_time_range(time_min, time_max)

      #Find the unique combinations of values for some of the jobs' attributes.
      value_sets = day_jobs.uniq.pluck(:user_id, :system_id, :command_name)
      if value_sets.empty?
        #There are no jobs, so create a dummy summary.
        user = User.select(:id).first
        system = System.select(:id).first
        #If there are no users or no systems, we can't create the dummy summary, so just return.
        return unless user && system
        #Create a dummy summary so summary() doesn't keep trying to create one.
        #TODO: figure out where this method comes from...
        sum = unscoped.find_or_initialize_by(
          date: date,
          user_id: user.id,
          system_id: system.id,
          command_name: ''
        )
        sum.cpu_time = 0
        sum.memory_time = 0
        sum.save!
      else
        value_sets.each do |set|
          summary_jobs = jobs.where(
            user_id: set[0],
            system_id: set[1],
            command_name: set[2]
          )
          summary = summary_jobs.summary(time_min, time_max)
          sum = unscoped.find_or_initialize_by(
            date: date,
            user_id: set[0],
            system_id: set[1],
            command_name: set[2]
          )
          sum.cpu_time = summary[:cpu_time]
          sum.memory_time = summary[:memory_time]
          sum.save!
        end
      end
    end

    ##
    #Returns a summary of jobs in the database
    #
    #When filtering, the same filters must be applied to both the Jobs and the JobSummaries. For example:
    # jobs = Bookie::Database::Job.merge(Bookie::Database::User.where(name: 'root'))
    # jobs = Bookie::Database::JobSummary.merge(Bookie::Database::User.where(name: 'root'))
    # puts summaries.summary(jobs, nil, nil)
    #
    # TODO: unit-test that summaries are created on UTC date boundaries?
    # TODO: doc better?
    def self.summary(jobs, time_min, time_max)
      time_min ||= jobs.minimum(:start_time)
      time_max ||= jobs.maximum(:end_time)

      #Are there actually any jobs?
      unless time_min && time_max
        time_min = time_max = Time.at(0)
      end

      date_min = time_min.utc.to_date
      rounded_date_min = false
      #Round date_min up.
      if date_min.to_utc_time < time_min
        date_min += 1
        rounded_date_min = true
      end
      date_max = time_max.utc.to_date

      #Is the interval large enough to cover any cached summaries?
      unless date_min < date_max
        #Nope; just return a regular summary.
        return jobs.summary(time_min, time_max)
      end

      jobs_in_range = jobs.by_time_range(time_min, time_max)
      #TODO: avoid these queries somehow?
      #(Add num_jobs_started and num_jobs_ended fields?)
      num_jobs = jobs_in_range.count
      successful = jobs_in_range.where(exit_code: 0).count
      cpu_time = 0
      memory_time = 0

      #TODO: check if num_jobs is zero so we can skip all this?
      if rounded_date_min
        #We need to get a summary for the chunk up to the first whole day.
        summary = jobs.summary(time_min, date_min.to_utc_time)
        cpu_time += summary[:cpu_time]
        memory_time += summary[:memory_time]
      end

      date_max_time = date_max.to_utc_time
      if date_max_time < time_max
        #We need to get a summary for the chunk after the last whole day.
        summary = jobs.summary(date_max_time, time_max)
        cpu_time += summary[:cpu_time]
        memory_time += summary[:memory_time]
      end

      date_range = date_min ... date_max

      #Now we can process the cached summaries.
      unscoped = self.unscoped
      summaries = where(date: date_range).order(:date).to_a
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
        if new_index == index && !(unscoped.where(date: date).any?)
          #Nope. Create the summaries.
          unscoped.summarize(date)
          #TODO: what if a Sender deletes the summaries right before this?
          self.where(date: date).each do |sum|
            cpu_time += sum.cpu_time
            memory_time += sum.memory_time
          end
        end
        index = new_index
      end

      {
        num_jobs: num_jobs,
        successful: successful,
        cpu_time: cpu_time,
        memory_time: memory_time,
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
