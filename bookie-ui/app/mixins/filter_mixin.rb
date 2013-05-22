module FilterMixin
  def each_filter(filters)
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
        filter = filters[type]
        #To do: handle case where the filter is invalid.
        num_values = filter[:types].length || 1
        next_value_index = value_index + num_values
        if next_value_index > filter_values.length
          flash.now[:error] = "Not enough filter values specified"
          #To do: figure out how to keep the bad filter in @prev_filters?
          return
        end
        values = filter_values[value_index ... next_value_index]
        yield type, values
        value_index = next_value_index
      end
    end
  end
end
