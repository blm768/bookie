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
    
    #To do: error messages
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
        when 'User'
          jobs = jobs.by_user_name(values[value_index])
          value_index += 1
        when 'Group'
          jobs = jobs.by_group_name(values[value_index])
          value_index += 1
        when 'System type'
          sys_type = Bookie::Database::SystemType.find_by_name(values[value_index])
          if sys_type
            jobs = jobs.by_system_type(sys_type)
            systems = systems.by_system_type(sys_type)
          else
            jobs = jobs.limit(0)
            systems = systems.limit(0)
          end
          value_index += 1
        when 'Time'
          summmary_start_time = Time.parse(values[value_index])
          summary_end_time = Time.parse(values[value_index + 1])
          value_index += 2
        end
      end
    end
    
    #To do: ordering?
    @jobs_summary = jobs.summary(summary_start_time, summary_end_time)
    @systems_summary = systems.summary(summary_start_time, summary_end_time)
    
    render :template => 'jobs/index'
  end
end
