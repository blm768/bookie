module FilterMixin
  #Yields type of filter, filter values, and whether the filter appears to be valid
  def each_filter(filter_value_types)
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
          flash_msg_now :error, "Only one filter of each type may be used at a time."
          next
        end
        used_filter_types.add(type)
        value_types = filter_value_types[type]
        unless value_types
          flash_msg_now :error, %{Unknown filter type "#{type}"}
          yield type, values, false
          next
        end
        num_values = value_types.length
        next_value_index = value_index + num_values
        values = filter_values[value_index ... next_value_index]
        if values.length < num_values
          error_field_blank(type)
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
          error_field_blank(type)
          yield type, values, false
          next
        end
        yield type, values, true
        value_index = next_value_index
      end
    end
  end

  def error_field_blank(filter_type)
    flash_msg_now :error, %{Filter "#{filter_type}" has blank fields.}
  end
end
