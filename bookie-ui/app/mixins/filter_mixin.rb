module FilterMixin
  #Yields type of filter, filter values, and whether the filter appears to be valid
  #
  #Returns an array containing any error messages
  #This array should be stashed in the @filter_errors instance variable of the controller
  #in order to make it available to the view.
  def each_filter(filter_value_types)
    errors = []

    filter_types = params[:filter_types]
    filter_values = params[:filter_values]
    if filter_types && filter_values
      filter_types.strip!
      filter_types = filter_types.split(',')
      filter_values.strip!
      filter_values = filter_values.split(',')
      #Filter values are URI-encoded twice to make sure commas are escaped.
      filter_values.map!{ |s| URI.unescape(s) }
      value_index = 0
      used_filter_types = Set.new
      filter_types.each do |type|
        if used_filter_types.include?(type)
          errors << "Only one filter of each type may be used at a time."
          next
        end
        used_filter_types.add(type)
        value_types = filter_value_types[type]
        unless value_types
          errors << %{Unknown filter type "#{type}"}
          yield type, values, false
          next
        end
        num_values = value_types.length
        next_value_index = value_index + num_values
        values = filter_values[value_index ... next_value_index]
        if values.length < num_values
          errors << error_field_blank(type)
          yield type, values, false
          next
        end
        has_blank = false
        values.each do |value|
          if value.blank?
            has_blank = true
            break
          end
        end
        if has_blank
          errors << error_field_blank(type)
          yield type, values, false
          next
        end
        yield type, values, true
        value_index = next_value_index
      end
    end

    errors
  end

  def error_field_blank(filter_type)
    %{Filter "#{filter_type}" has blank fields.}
  end

  def parse_time_range(start_time_text, end_time_text)
    start_time = nil
    end_time = nil

    begin
      start_time = Time.parse(start_time_text)
    rescue
      flash_msg_now :error, %{Invalid start time '#{start_time_text}"}
      return nil
    end
    begin
      end_time = Time.parse(end_time_text)
    rescue => e
      flash_msg_now :error, %{Invalid end time "#{end_time_text}"}
      return nil
    end
    start_time ... end_time
  end
end
