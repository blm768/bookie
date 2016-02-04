require 'spec_helper'

describe Bookie::Database::User do
  it "correctly filters by name" do
    users = Bookie::Database::User.by_name('test').to_a
    expect(users.length).to eql 1
    expect(users[0].name).to eql 'test'
  end

  describe "#find_or_create" do
    it "creates the user if needed" do
      Bookie::Database::User.expects(:"create!").twice
      user = Bookie::Database::User.find_or_create!('me')
      user = Bookie::Database::User.find_or_create!('me', {})
    end

    it "returns the cached user if one exists" do
      user = Bookie::Database::User.find_by(name: 'root')
      known_users = {'root' => user}
      expect(Bookie::Database::User.find_or_create!('root', known_users)).to equal user
    end

    it "queries the database when this user is not cached" do
      user = Bookie::Database::User.find_by!(name: 'root')
      known_users = {}
      Bookie::Database::User.expects(:find_by).returns(user).twice
      Bookie::Database::User.expects(:"create!").never
      expect(Bookie::Database::User.find_or_create!('root', known_users)).to eql user
      expect(Bookie::Database::User.find_or_create!('root', nil)).to eql user
      expect(known_users).to include(user.name)
    end
  end

  it "validates fields" do
    expect(Bookie::Database::User.new(name: 'test').valid?).to eql true

    #Check for null/empty fields
    user = Bookie::Database::User.new(name: nil)
    expect(user.valid?).to eql false

    user = Bookie::Database::User.new(name: '')
    expect(user.valid?).to eql false
  end
end
