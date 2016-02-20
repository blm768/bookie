module SummaryHelpers
  #Creates summaries (using a relation's summary method) under different conditions
  def create_summaries(obj, base_time)
    base_start = base_time
    base_end   = base_time + 30.hours
    summaries = {
      :all => obj.summary,
      :all_constrained => obj.summary(base_start ... base_end),
      :wide => obj.summary(base_start - 1.hours ... base_end + 1.hours),
      :clipped => obj.summary(base_start + 5.hours ... base_start + 25.hours),
      :empty => obj.summary(base_start ... base_start),
    }

    #TODO: move?
    if obj.respond_to?(:by_command_name)
      summaries[:all_filtered] = obj.by_command_name('vi').summary(base_start ... base_end)
    end

    summaries
  end
end
