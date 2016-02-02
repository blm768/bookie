require 'spec_helper'

describe Bookie::Database::User do
  it "correctly filters by name" do
    users = Bookie::Database::User.by_name('test').to_a
    expect(users.length).to eql 2
    users.each do |user|
      expect(user.name).to eql 'test'
    end
  end

  it "correctly filters by group" do
    expect(Bookie::Database::User.by_group(Bookie::Database::Group.find_by_name('admin')).count).to eql 2
    expect(Bookie::Database::User.by_group(Bookie::Database::Group.find_by_name('root')).count).to eql 1
  end

  it "correctly filters by group name" do
    expect(Bookie::Database::User.by_group_name('admin').count).to eql 2
    expect(Bookie::Database::User.by_group_name('fake_group').count).to eql 0
  end

  describe "#find_or_create" do
    before(:each) do
      @group = Bookie::Database::Group.find_by_name('admin')
    end

    it "creates the user if needed" do
      Bookie::Database::User.expects(:"create!").twice
      user = Bookie::Database::User.find_or_create!('me', @group)
      user = Bookie::Database::User.find_or_create!('me', @group, {})
    end

    it "returns the cached user if one exists" do
      user = Bookie::Database::User.find_by_name('root')
      known_users = {['root', user.group] => user}
      expect(Bookie::Database::User.find_or_create!('root', user.group, known_users)).to equal user
    end

    it "queries the database when this user is not cached" do
      user = Bookie::Database::User.find_by_name_and_group_id('root', 1)
      known_users = {}
      Bookie::Database::User.expects(:find_by_name_and_group_id).returns(user).twice
      Bookie::Database::User.expects(:"create!").never
      expect(Bookie::Database::User.find_or_create!('root', user.group, known_users)).to eql user
      expect(Bookie::Database::User.find_or_create!('root', user.group, nil)).to eql user
      expect(known_users).to include ['root', user.group]
    end
  end

  it "validates fields" do
    fields = {
      :group => Bookie::Database::Group.first,
      :name => 'test',
    }

    expect(Bookie::Database::User.new(fields).valid?).to eql true

    fields.each_key do |field|
      user = Bookie::Database::User.new(fields)
      user.method("#{field}=".intern).call(nil)
      expect(user.valid?).to eql false
    end

    user = Bookie::Database::User.new(fields)
    user.name = ''
    expect(user.valid?).to eql false
  end
end
