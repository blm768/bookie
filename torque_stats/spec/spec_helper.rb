if ENV['COVERAGE']
  require 'simplecov'
  SimpleCov.start
end

require 'mocha_standalone'

RSpec.configure do |config|
  config.mock_with(:mocha)
end

require 'torque_stats'

