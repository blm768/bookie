module FilterMixin
  #Yields type of filter, filter values, and whether the filter appears to be valid
  #
  #Returns an array containing any error messages
  #This array should be stashed in the @filter_errors instance variable of the controller
  #in order to make it available to the view.
  def each_filter(filter_types)
    errors = []

    filter_types.each do |name, filter_type|
      values = params[name]
      next unless values
      values = [values] unless values.is_a?Array
      #TODO: handle hash parameters?
#      if values.length < num_values
#        errors << error_field_blank(type)
#        yield type, values, false
#        next
#      end
      has_blank = false
      values.each do |value|
        if value.blank?
          has_blank = true
          break
        end
      end
      if has_blank
        errors << error_field_blank(name)
        yield name, values, false
        next
      end
      yield name, values, true
    end

    errors
  end

  def error_field_blank(name)
    %{Filter "#{name.to_s.humanize}" has blank fields.}
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
