module FilterMixin
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
      filter_types.each do |type|
        value_types = filter_value_types[type]
        unless value_types
          flash_msg_now :error, %{Unknown filter type "#{type}"}
          next
        end
        num_values = value_types.length
        next_value_index = value_index + num_values
        values = filter_values[value_index ... next_value_index]
        if filter_values.length < num_values
          #To do: figure out how to keep the bad filter in @prev_filters?
          error_field_blank
          next
        end
        values.each do |value|
          error_field_blank if value.blank?
        end
        yield type, values
        value_index = next_value_index
      end
    end
  end

  def error_field_blank
    flash_msg_now :error, "Filter fields must not be blank."
  end
end
