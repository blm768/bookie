require 'bookie_database_all'

class SystemsController < ApplicationController
  before_filter :require_login

  FILTERS = {
    system_type: :text,
    time: :datetime_range,
  }

  include FilterMixin

  def index
    systems = Bookie::Database::System.order(:name)
    capacities = Bookie::Database::SystemCapacity

    time_min, time_max = nil
    @prev_filters = []

    @filter_errors = each_filter(FILTERS) do |type, values, valid|
      @prev_filters << [type, values]
      next unless valid
      case type
      when :system_type
        sys_type = Bookie::Database::SystemType.find_by_name(values[0])
        if sys_type
          systems = systems.where(system_type: sys_type)
        else
          #TODO: use '.none'?
          systems = systems.where('1=0')
          flash_msg_now :error, %{Unknown system type "#{values[0]}"}
        end
      when :time
        time_range = parse_time_range(*values)
        time_min = time_range.begin
        time_max = time_range.end
      end
    end

    #TODO: replace with working code.
    @systems_summary = capacities.summary(time_min, time_max)
    #systems = systems.by_time_range(time_min, time_max) if time_range
    @systems = systems
  end

  def show
    #@system = Bookie::Database::System.find
  end
end

