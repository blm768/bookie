require 'spec_helper'

describe Bookie::Database::User do
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
