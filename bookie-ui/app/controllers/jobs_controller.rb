require 'date'

require 'filter'

class JobsController < ApplicationController
  PAGE_SIZE = 20
  
  FILTER_ARG_COUNTS = {
    'System' => 1,
    'User' => 1,
    'Group' => 1,
    'System type' => 1,
    'Time' => 2
  }
  
  include FilterMixin

  def index
    #To do: optimize as local variable?
    jobs = Bookie::Database::Job
    systems = Bookie::Database::System
        
    summary_start_time = nil
    summary_end_time = nil
    
    @page_num = params[:page].to_i
    @page_num = 1 unless @page_num && @page_num > 0
        
    #Passed to the view to make the filter form's contents persistent
    @prev_filters = []
    
    #To do: error on empty fields?
    each_filter(FILTER_ARG_COUNTS) do |name, values|
      case name
      when 'System'
        jobs = jobs.by_system_name(values[0])
        systems = systems.by_name(values[0])
        @prev_filters << ['System', values]
      when 'User'
        jobs = jobs.by_user_name(values[0])
        @prev_filters << ['User', values]
      when 'Group'
        jobs = jobs.by_group_name(values[0])
        @prev_filters << ['Group', values]
      when 'System type'
        value = values[value_index]
        sys_type = Bookie::Database::SystemType.find_by_name(value)
        if sys_type
          jobs = jobs.by_system_type(sys_type)
          systems = systems.by_system_type(sys_type)
        else
          jobs = jobs.limit(0)
          systems = systems.limit(0)
        end
        value_index += 1
        @prev_filters << ['System type', [value]]
      when 'Time'
        start_time_text = values[value_index]
        end_time_text = values[value_index + 1]
        begin
          summmary_start_time = Time.parse(start_time_text)
        rescue
          flash[:error] = "Invalid start time '#{start_time_text}'"
        end
        begin
          summary_end_time = Time.parse(end_time_text)
        rescue
          flash[:error] = "Invalid end time '#{end_time_text}'"
        end
        value_index += 2
        @prev_filters << ['Time', [start_time_text, end_time_text]]
      end
    end
    
    #To do: ordering?
    @jobs_summary = jobs.summary(summary_start_time, summary_end_time)
    @systems_summary = systems.summary(summary_start_time, summary_end_time)
    
    #To be passed to the view
    @include_details = (params[:details] == "true")
    @page_start = PAGE_SIZE * (@page_num - 1)
    @page_end = @page_start + PAGE_SIZE
    num_jobs = @jobs_summary[:jobs].length
    @num_pages = num_jobs / PAGE_SIZE + ((num_jobs % PAGE_SIZE) > 0 ? 1 : 0)
        
    render :template => 'jobs/index'
  end
end
