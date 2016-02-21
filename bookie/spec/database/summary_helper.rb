require 'spec_helper'

module SummaryHelpers
  #Creates summaries (using a relation's summary method) under different conditions

  BASE_START = Helpers::BASE_TIME
  BASE_END = BASE_START + 30.hours

  CLIP_MARGIN = 1.hours + 30.minutes
  CLIPPED_TIME_INTERVAL = BASE_END - BASE_START - 2 * CLIP_MARGIN

  WIDE_MARGIN = 1.hours
  WIDE_TIME_INTERVAL = BASE_END - BASE_START - 2 * WIDE_MARGIN

  def create_summaries(obj)
    {
      :all => obj.summary(nil, nil),
      :all_constrained => obj.summary(BASE_START, BASE_END),
      :wide => obj.summary(BASE_START - WIDE_MARGIN, BASE_END + WIDE_MARGIN),
      :clipped => obj.summary(BASE_START + CLIP_MARGIN, BASE_END - CLIP_MARGIN),
      :empty => obj.summary(BASE_START, BASE_START),
    }
  end
end
