#TODO: revise unit tests.
#TODO: see which methods we're still using.

##
#Reopened to add some useful methods
class Range
  ##
  #If end < begin, returns an empty range (begin ... begin)
  #Otherwise, returns the original range
  def normalized
   if self.end < self.begin
     self.begin ... self.begin
   else
    self
   end
  end

  ##
  #Converts the range to an equivalent exclusive range (one where exclude_end? is true)
  #
  #Only works for ranges with discrete steps between values (i.e. integers)
  def exclusive
    if exclude_end?
      self
    else
      Range.new(self.begin, self.end + 1, true)
    end
  end

  ##
  #Returns whether the range is empty
  #
  #A range is empty if end < begin or if begin == end and exclude_end? is true.
  #
  #TODO: handle infinite values?
  def empty?
    if exclude_end?
      self.end <= self.begin
    else
      self.end < self.begin
    end
  end
end

##
#Reopened to add some useful methods
class Date
  ##
  #Converts the Date to a Time, using UTC as the time zone
  def to_utc_time
    Time.utc(year, month, day)
  end
end

