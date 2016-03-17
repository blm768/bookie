require 'bookie_database_all'

class JobsController < ApplicationController
  before_filter :require_login

  JOBS_PER_PAGE = 20

  FILTERS = {
    system: :text,
    user: :text,
    system_type: :text,
    command_name: :text,
    time: :datetime_range,
  }

  include FilterMixin

  def index
    jobs = Bookie::Database::Job
    summaries = Bookie::Database::JobSummary
    system_caps = Bookie::Database::SystemCapacity

    @page_num = params[:page].to_i
    @page_num = 1 unless @page_num && @page_num > 0

    time_min, time_max = nil

    #Passed to the view to make the filter form's contents persistent
    @prev_filters = []

    @filter_errors = each_filter(FILTERS) do |type, values, valid|
      @prev_filters << [type, values]
      next unless valid
      case type
      when :system
        sys_name = values[0]
        #TODO: validate that this system exists!
        sys = Bookie::Database::System.where(name: sys_name).first
        if sys then
          jobs = jobs.where(system: sys)
          summaries = summaries.where(system: sys)
          system_caps = system_caps.where(system: sys)
        else
          jobs = jobs.where('1=0')
          summaries = summaries.where('1=0')
          system_caps = system_caps.where('1=0')
          flash_msg_now :error, "Unrecognized system: #{sys_name}"
        end
      when :user
        jobs = jobs.by_user_name(values[0])
        summaries = summaries.by_user_name(values[0])
      when :system_type
        sys_type = Bookie::Database::SystemType.find_by(name: values[0])
        if sys_type
          jobs = jobs.by_system_type(sys_type)
          summaries = summaries.by_system_type(sys_type)
          system_caps = system_caps.by_system_type(sys_type)
        else
          jobs = jobs.where('1=0')
          summaries = summaries.where('1=0')
          system_caps = system_caps.where('1=0')
          flash_msg_now :error, %{Unknown system type "#{values[0]}"}
        end
      when :command_name
        jobs = jobs.where(command_name: values[0])
        summaries = summaries.where(command_name: values[0])
      when :time
        time_range = parse_time_range(*values)
        time_min = time_range.begin
        time_max = time_range.end
      end
    end

    @jobs_summary = summaries.summary(jobs, time_min, time_max)

    @systems_summary = system_caps.summary(time_min, time_max)

    avail_cpu_time = @systems_summary[:avail_cpu_time]
    avail_mem_time = @systems_summary[:avail_memory_time]
    @combined_summary = {
      :cpu_time => avail_cpu_time == 0 ? 0.0 : @jobs_summary[:cpu_time] / avail_cpu_time,
      :memory => avail_mem_time == 0 ? 0.0 : @jobs_summary[:memory_time] / avail_mem_time,
    }

    #To be passed to the view
    @show_details = (params[:show_details] == "true")
    if @show_details
      if time_min
        jobs = jobs.by_time_range_inclusive(time_min, time_max)
      end
      jobs = jobs.order(:end_time)
      @page_start = JOBS_PER_PAGE * (@page_num - 1)
      num_jobs = @jobs_summary[:num_jobs]
      @num_pages = num_jobs / JOBS_PER_PAGE + ((num_jobs % JOBS_PER_PAGE) > 0 ? 1 : 0)
      @num_pages = 1 if @num_pages == 0
      @jobs = jobs.limit(JOBS_PER_PAGE).offset(@page_start).includes(:user, :system, :system_type).to_a
    end

    respond_to do |format|
      format.html
      format.json
    end
  end

  #Options available in enum-like filters (such as system type)
  def self.filter_options
    { sys_type: Bookie::Database::SystemType.pluck(:name) }
  end
end
