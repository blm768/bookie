require 'bookie_database_all'

require 'date'

class JobsController < ApplicationController
  PAGE_SIZE = 20
  
  FILTER_ARG_COUNTS = {
    'System' => 1,
    'User' => 1,
    'Group' => 1,
    'System type' => 1,
    'Command name' => 1,
    'Time' => 2,
  }
  
  include FilterMixin

  def index
    jobs = Bookie::Database::Job
    systems = Bookie::Database::System
        
    summary_start_time = nil
    summary_end_time = nil
    
    @page_num = params[:page].to_i
    @page_num = 1 unless @page_num && @page_num > 0
        
    #Passed to the view to make the filter form's contents persistent
    @prev_filters = []
    
    #To do: error on empty fields?
    each_filter(FILTER_ARG_COUNTS) do |type, values|
      case type
      when 'System'
        jobs = jobs.by_system_name(values[0])
        systems = systems.by_name(values[0])
      when 'User'
        jobs = jobs.by_user_name(values[0])
      when 'Group'
        jobs = jobs.by_group_name(values[0])
      when 'System type'
        sys_type = Bookie::Database::SystemType.find_by_name(values[0])
        if sys_type
          jobs = jobs.by_system_type(sys_type)
          systems = systems.by_system_type(sys_type)
        else
          jobs = jobs.limit(0)
          systems = systems.limit(0)
        end
      when 'Command name'
        jobs = jobs.by_command_name(values[0])
      when 'Time'
        start_time_text = values[0]
        end_time_text = values[1]
        begin
          summary_start_time = Time.parse(start_time_text)
        rescue
          flash.now[:error] = "Invalid start time '#{start_time_text}'"
        end
        begin
          summary_end_time = Time.parse(end_time_text)
        rescue
          flash.now[:error] = "Invalid end time '#{end_time_text}'"
        end
      end
      @prev_filters << [type, values]
    end
    
    #To do: ordering?
    @jobs_summary = jobs.summary(summary_start_time, summary_end_time)
    @systems_summary = systems.summary(summary_start_time, summary_end_time)
    
    
    avail_cpu_time = @systems_summary[:avail_cpu_time]
    avail_mem_time = @systems_summary[:avail_memory_time]
    @combined_summary = {
      :cpu_time => avail_cpu_time == 0 ? 0.0 : @jobs_summary[:cpu_time] / avail_cpu_time,
      :memory => avail_mem_time == 0 ? 0.0 : @jobs_summary[:memory_time] / avail_mem_time,
    }
    
    #To be passed to the view
    @show_details = (params[:show_details] == "true")
    if @show_details
      @page_start = PAGE_SIZE * (@page_num - 1)
      @page_end = @page_start + PAGE_SIZE
      num_jobs = @jobs_summary[:jobs].length
      @num_pages = num_jobs / PAGE_SIZE + ((num_jobs % PAGE_SIZE) > 0 ? 1 : 0)
    end
    
    respond_to do |format|
      format.html
      format.json
    end
  end
end
