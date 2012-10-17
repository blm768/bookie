if ENV['COVERAGE']
  require 'simplecov'
  SimpleCov.start
end

require 'mocha_standalone'

require 'bookie'

RSpec.configure do |config|
  config.mock_with(:mocha)
end