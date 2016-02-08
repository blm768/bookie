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
      user = Bookie::Database::User.find_or_create!(1, 'me')
      user = Bookie::Database::User.find_or_create!(1, 'me', {})
    end

    it "returns the cached user if one exists" do
      user = Bookie::Database::User.find_by(id: 1, name: 'root')
      known_users = {1 => user}
      expect(Bookie::Database::User.find_or_create!(1, 'root', known_users)).to equal user
    end

    it "queries the database when this user is not cached" do
      user = Bookie::Database::User.find_by!(id: '1', name: 'root')
      known_users = {}
      Bookie::Database::User.expects(:find_by).returns(user).twice
      Bookie::Database::User.expects(:"create!").never
      expect(Bookie::Database::User.find_or_create!(user.id, user.name, known_users)).to eql user
      expect(Bookie::Database::User.find_or_create!(user.id, user.name, nil)).to eql user
      expect(known_users).to include(user.id)
    end
  end

  it "validates fields" do
    expect(Bookie::Database::User.new(id: 1, name: 'test').valid?).to eql true

    #Check for null/empty fields
    user = Bookie::Database::User.new(id: 1, name: nil)
    expect(user.valid?).to eql false

    user = Bookie::Database::User.new(id: 1, name: '')
    expect(user.valid?).to eql false

    user = Bookie::Database::User.new(id: nil, name: 'test')
    expect(user.valid?).to eql false
  end
end
