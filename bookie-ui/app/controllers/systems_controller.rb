class SystemsController < ApplicationController
  def index
    #To do: add each_with_relations to System?
    @systems = Bookie::Database::System
    
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
        when 'Hostname'
          systems = systems.by_name(values[value_index])
          value_index += 1
        when 'Time'
          summary_start_time = Time.parse(values[value_index])
          summary_end_time = Time.parse(values[value_index + 1])
          value_index += 2
        end
      end
    end
    
    @systems_summary = @systems.summary(summary_start_time, summary_end_time)
    
    render :template => 'systems/index'
  end
end