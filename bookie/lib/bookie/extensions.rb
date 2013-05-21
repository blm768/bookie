
##
#Reopened to add some useful methods
class Range
  ##
  #If end < begin, returns an empty range (begin ... begin)
  #Otherwise, returns the original range
  def normalized
    return self.begin ... self.begin if self.end < self.begin
    self
  end
  
  ##
  #Returns the empty status of the range
  #
  #A range is empty if end < begin or if begin == end and exclude_end? is true.
  def empty?
    (self.end < self.begin) || (exclude_end? && (self.begin == self.end))
  end

#This code probably works, but we're not using it anywhere.  
#   def intersection(other)
#     self_n = self.normalized
#     other = other.normalized
#     
#     new_begin, new_end, exclude_end = nil
#     
#     if self_n.cover?(other.begin)
#       new_first = other.begin
#     elsif other.cover?(self_n.begin)
#       new_first = self_n.begin
#     end
#     
#     return self_n.begin ... self_n.begin unless new_first
#     
#     if self_n.cover?(other.end)
#       unless other.exclude_end? && other.end == self_n.begin
#         new_end = other.end
#         exclude_end = other.exclude_end?
#       end
#     elsif other.cover?(self_n.end)
#       unless self_n.exclude_end? && self_n.end == other.begin
#         new_end = self_n.end
#         exclude_end = self_n.exclude_end?
#       end
#     end
#     
#     #If we still haven't found new_end, try one more case:
#     unless new_end
#       if self_n.end == other.end
#         #We'll only get here if both ranges exclude their ends and have the same end.
#         new_end = self_n.end
#         exclude_end = true
#       end
#     end
#     
#     return self_n.begin ... self_n.begin unless new_end
# 
#     Range.new(new_begin, new_end, exclude_end)
#   end
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

