class SystemsController < ApplicationController
  FILTERS = {
    'Hostname' => [:text],
    'System type' => [:sys_type],
    'Time' => [:text, :text],
  }
  
  include FilterMixin

  def index
    #To do: add each_with_relations to System?
    systems = Bookie::Database::System

    summary_time_range = nil
    @prev_filters = []
    
    each_filter(FILTERS) do |type, values, valid|
      @prev_filters << [type, values]
      next unless valid
      case type
      when 'Hostname'
        systems = systems.by_name(values[0])
      when 'System type'
        sys_type = Bookie::Database::SystemType.find_by_name(values[0])
        if sys_type
          systems = systems.by_system_type(sys_type)
        else
          systems = systems.where('1=0')
          flash_msg_now :error, %{Unknown system type "#{values[0]}"}
        end
      when 'Time'
        summary_time_range = parse_time_range(*values)
      end
    end
    
    @systems_summary = systems.summary(summary_time_range)
    @systems = systems.by_time_range_inclusive(summary_time_range)
    
    render :template => 'systems/index'
  end
end
