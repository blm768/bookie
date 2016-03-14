require 'spec_helper'

require 'active_record'

class TestConfig
  include Bookie::ConfigClass

  attr_accessor :valid_flag

  property :anything
  property :string, type: String
  property :maybe_integer, type: Integer, allow_nil: true
  property :not_nil, allow_nil: false

  validate_self do

  end
end

#TODO: flesh out.
describe Bookie::ConfigClass do
  it "correctly verifies types"

  it "correctly handles nil fields"
end
