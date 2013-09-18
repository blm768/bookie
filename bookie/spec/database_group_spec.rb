require 'spec_helper'

describe Bookie::Database do
  Helpers.use_cleaner(self)  

  describe Bookie::Database::Group do
    describe "#find_or_create" do
      it "creates the group if needed" do
        Bookie::Database::Group.expects(:"create!")
        Bookie::Database::Group.find_or_create!('non_root')
      end
      
      it "returns the cached group if one exists" do
        group = Bookie::Database::Group.find_by_name('root')
        known_groups = {'root' => group}
        Bookie::Database::Group.find_or_create!('root', known_groups).should equal group
      end
      
      it "queries the database when this group is not cached" do
        group = Bookie::Database::Group.find_by_name('root')
        known_groups = {}
        Bookie::Database::Group.expects(:find_by_name).returns(group).twice
        Bookie::Database::Group.expects(:"create!").never
        Bookie::Database::Group.find_or_create!('root', known_groups).should eql group
        Bookie::Database::Group.find_or_create!('root', nil).should eql group
        known_groups.should include 'root'
      end
    end
    
    it "validates the name field" do
      group = Bookie::Database::Group.new(:name => nil)
      group.valid?.should eql false
      group.name = ''
      group.valid?.should eql false
      group.name = 'test'
      group.valid?.should eql true
    end
  end
end

