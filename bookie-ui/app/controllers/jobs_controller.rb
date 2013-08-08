require 'bookie_database_all'

class JobsController < ApplicationController
  JOBS_PER_PAGE = 20
  
  FILTERS = {
    'System' => [:text],
    'User' => [:text],
    'Group' => [:text],
    'System type' => [:sys_type],
    'Command name' => [:text],
    'Time' => [:text, :text],
  }

  include FilterMixin

  def index
    jobs = Bookie::Database::Job
    summaries = Bookie::Database::JobSummary
    systems = Bookie::Database::System
        
    @page_num = params[:page].to_i
    @page_num = 1 unless @page_num && @page_num > 0

    summary_time_range = nil
        
    #Passed to the view to make the filter form's contents persistent
    @prev_filters = []
    
    each_filter(FILTERS) do |type, values, valid|
      @prev_filters << [type, values]
      next unless valid
      case type
      when 'System'
        jobs = jobs.by_system_name(values[0])
        summaries = summaries.by_system_name(values[0])
        systems = systems.by_name(values[0])
      when 'User'
        jobs = jobs.by_user_name(values[0])
        summaries = summaries.by_user_name(values[0])
      when 'Group'
        jobs = jobs.by_group_name(values[0])
        summaries = summaries.by_group_name(values[0])
      when 'System type'
        sys_type = Bookie::Database::SystemType.find_by_name(values[0])
        if sys_type
          jobs = jobs.by_system_type(sys_type)
          summaries = summaries.by_system_type(sys_type)
          systems = systems.by_system_type(sys_type)
        else
          jobs = jobs.where('1=0')
          summaries = summaries.where('1=0')
          systems = systems.where('1=0')
          flash_msg_now :error, %{Unknown system type "#{values[0]}"}
        end
      when 'Command name'
        jobs = jobs.by_command_name(values[0])
        summaries = summaries.by_command_name(values[0])
      when 'Time'
        summary_time_range = parse_time_range(*values)
      end
    end

    #To do: remove.
    summary_time_range ||= Time.utc(2012) ... Time.utc(2012) + 2.days
    
    #To do: ordering?
    @jobs_summary = summaries.summary(:range => summary_time_range, :jobs => jobs)

    @systems_summary = systems.summary(summary_time_range)

    avail_cpu_time = @systems_summary[:avail_cpu_time]
    avail_mem_time = @systems_summary[:avail_memory_time]
    @combined_summary = {
      :cpu_time => avail_cpu_time == 0 ? 0.0 : @jobs_summary[:cpu_time] / avail_cpu_time,
      :memory => avail_mem_time == 0 ? 0.0 : @jobs_summary[:memory_time] / avail_mem_time,
    }
    
    #To be passed to the view
    @show_details = (params[:show_details] == "true")
    if @show_details
      if summary_time_range
        jobs = jobs.by_time_range_inclusive(summary_time_range)
      end
      jobs = jobs.order(:end_time)
      @page_start = JOBS_PER_PAGE * (@page_num - 1)
      num_jobs = @jobs_summary[:num_jobs]
      @num_pages = num_jobs / JOBS_PER_PAGE + ((num_jobs % JOBS_PER_PAGE) > 0 ? 1 : 0)
      @num_pages = 1 if @num_pages == 0
      @jobs = jobs.limit(JOBS_PER_PAGE).offset(@page_start)
    end
    
    respond_to do |format|
      format.html
      format.json
    end
  end

  #Options available in enum-like filters (such as system type)
  def self.filter_options
    {
      :sys_type => Bookie::Database::SystemType.select(:name).to_a.map{ |t| t.name }
    }
  end
end
