require 'bookie_database_all'

require 'date'

class JobsController < ApplicationController
  JOBS_PER_PAGE = 20
  
  FILTERS = {
    'System' => {:types => [:text]},
    'User' => {:types => [:text]},
    'Group' => {:types => [:text]},
    'System type' => {:types => [:sys_type]},
    'Command name' => {:types => [:text]},
    'Time' => {:types => [:text, :text]},
  }

  FILTER_OPTIONS = {
    :sys_type => ['test']
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
    
    #To do: prevent duplicate filters?
    each_filter(FILTERS) do |type, values|
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
        summary_start_time = nil
        summary_end_time = nil
    
        start_time_text = values[0]
        end_time_text = values[1]
        begin
          summary_start_time = Time.parse(start_time_text)
        rescue
          flash_msg_now :error, %{Invalid start time '#{start_time_text}"}
        end
        begin
          summary_end_time = Time.parse(end_time_text)
        rescue => e
          flash_msg_now :error, %{Invalid end time "#{end_time_text}"}
          flash_msg_now :error, e.to_s
        end
        if summary_start_time && summary_end_time
          summary_time_range = summary_start_time ... summary_end_time
        end
      end
      @prev_filters << [type, values]
    end
    
    #To do: remove
    summary_time_range ||= Time.utc(2012) ... Time.utc(2012) + 2.days
    
    #To do: ordering?
    Bookie::Database::JobSummary.delete_all
    @jobs_summary = summaries.summary(:range => summary_time_range, :jobs => jobs)

    @systems_summary = systems.summary(summary_time_range)

    #Options available in enum-like filters
    @filter_options = {
      :sys_type => Bookie::Database::SystemType.select(:name).all.map{ |t| t.name }
    }
    
    
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
end
