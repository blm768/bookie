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

