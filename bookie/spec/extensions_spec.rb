require 'spec_helper'

describe Range do
  describe "#normalized" do
    it "correctly normalizes" do
      expect((1 .. 2).normalized).to eql(1 .. 2)
      expect((1 .. 1).normalized).to eql(1 .. 1)
      expect((1 ... 1).normalized).to eql(1 ... 1)
      expect((1 .. 0).normalized).to eql(1 ... 1)
      expect((1 ... 0).normalized).to eql( 1 ... 1 )
    end
  end

  describe "empty?" do
    it "correctly determines emptiness" do
      expect((1 .. 2).empty?).to eql false
      expect((1 .. 1).empty?).to eql false
      expect((1 ... 2).empty?).to eql false
      expect((1 ... 1).empty?).to eql true
      expect((1 .. 0).empty?).to eql true
      expect((1 ... 0).empty?).to eql true
    end
  end
end

