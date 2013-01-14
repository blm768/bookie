class SystemsController < ApplicationController
  def index
    #To do: add each_with_relations to System?
    @systems = Bookie::Database::System
    
    summary_start_time = nil
    summary_end_time = nil
    
    types = params[:filter_types]
    values = params[:filter_values]
    
    @prev_filters = []
    
    #To do: error messages
    if types && values
      types.strip!
      types = types.split(',')
      values.strip!
      values = values.split(',')
      value_index = 0
      types.each do |type|
        case type
        when 'Hostname'
          value = values[value_index]
          @systems = @systems.by_name(value)
          value_index += 1
          @prev_filters << ['Hostname', [value]]
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
    
    @systems_summary = @systems.summary(summary_start_time, summary_end_time)
    
    render :template => 'systems/index'
  end
end