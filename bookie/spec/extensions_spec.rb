require 'spec_helper'

describe Range do
  describe "#normalized" do
    it "correctly normalizes" do
      (1 .. 2).normalized.should eql (1 .. 2)
      (1 .. 1).normalized.should eql (1 .. 1)
      (1 ... 1).normalized.should eql (1 ... 1)
      (1 .. 0).normalized.should eql (1 ... 1)
      (1 ... 0).normalized.should eql ( 1 ... 1 )
    end
  end

  describe "empty?" do
    it "correctly determines emptiness" do
      (1 .. 2).empty?.should eql false
      (1 .. 1).empty?.should eql false
      (1 ... 2).empty?.should eql false
      (1 ... 1).empty?.should eql true
      (1 .. 0).empty?.should eql true
      (1 ... 0).empty?.should eql true
    end
  end
end

describe Date do
  describe "to_utc_time" do
    it "gives the correct time" do
      Date.new(2012, 1, 1).to_utc_time.should eql Time.utc(2012, 1, 1)
    end
  end
end

describe Integer do
  describe "seconds_to_duration_string" do
    it "produces the correct string" do
      i = 1.seconds + 2.minutes + 3.hours + 4.days + 5.weeks
      i.seconds_to_duration_string.should eql "5 weeks, 4 days, 03:02:01"
    end
  end
end

