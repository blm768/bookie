require 'date'

class BadDateError < RangeError

end

class JobsController < ApplicationController
  def index
    #To do: optimize as local variable?
    jobs = Bookie::Database::Job
    systems = Bookie::Database::System
        
    summary_start_time = nil
    summary_end_time = nil
    
    types = params[:filter_types]
    values = params[:filter_values]
    
    #Passed to the view to make the filter form's contents persistent
    @prev_filters = []
    
    #To do: error on empty fields?
    if types && values
      types.strip!
      types = types.split(',')
      values.strip!
      values = values.split(',')
      value_index = 0
      types.each do |type|
        case type
        when 'System'
          value = values[value_index]
          jobs = jobs.by_system_name(value)
          systems = systems.by_name(value)
          value_index += 1
          @prev_filters << ['System', [value]]
        when 'User'
          value = values[value_index]
          jobs = jobs.by_user_name(value)
          value_index += 1
          @prev_filters << ['User', [value]]
        when 'Group'
          value = values[value_index]
          jobs = jobs.by_group_name(value)
          value_index += 1
          @prev_filters << ['Group', [value]]
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
    end
    
    #To do: ordering?
    @jobs_summary = jobs.summary(summary_start_time, summary_end_time)
    @systems_summary = systems.summary(summary_start_time, summary_end_time)
    
    #To be passed to the view
    @filter_types = types
    @filter_values = values
    @include_details = (params[:details] == "true")
    
    render :template => 'jobs/index'
  end
end
