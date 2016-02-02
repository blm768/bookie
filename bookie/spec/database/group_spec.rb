require 'spec_helper'

describe Bookie::Database::Group do
  describe "#find_or_create" do
    it "creates the group if needed" do
      Bookie::Database::Group.expects(:"create!")
      Bookie::Database::Group.find_or_create!('non_root')
    end

    it "returns the cached group if one exists" do
      group = Bookie::Database::Group.find_by(name: 'root')
      known_groups = {'root' => group}
      expect(Bookie::Database::Group.find_or_create!('root', known_groups)).to equal group
    end

    it "queries the database when this group is not cached" do
      group = Bookie::Database::Group.find_by(name: 'root')
      known_groups = {}
      Bookie::Database::Group.expects(:find_by).returns(group).twice
      Bookie::Database::Group.expects(:"create!").never
      expect(Bookie::Database::Group.find_or_create!('root', known_groups)).to eql group
      expect(Bookie::Database::Group.find_or_create!('root', nil)).to eql group
      expect(known_groups).to include 'root'
    end
  end

  it "validates the name field" do
    group = Bookie::Database::Group.new(:name => nil)
    expect(group.valid?).to eql false
    group.name = ''
    expect(group.valid?).to eql false
    group.name = 'test'
    expect(group.valid?).to eql true
  end
end
