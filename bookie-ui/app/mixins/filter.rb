module FilterMixin
  def each_filter(filters)
    filter_names = params[:filters]
    filter_values = params[:filter_values]
    if filter_names && filter_values
      filter_names.strip!
      filter_names = filter_names.split(',')
      filter_values.strip!
      filter_values = values.split(',')
      value_index = 0
      filters.each do |name, num_values|
        next_filter_index = filter_index + num_values
        values = filter_values[filter_index ... next_filter_index]
        yield name, values
        filter_index = next_filter_index
      end
    end
  end
end
