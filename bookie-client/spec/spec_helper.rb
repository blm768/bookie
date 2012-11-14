if ENV['COVERAGE']
  require 'simplecov'
  SimpleCov.start
end

#For testing
$LOAD_PATH.concat Dir.glob(File.join(Dir.pwd, "../*/lib"))

require 'mocha_standalone'

require 'bookie-client'

RSpec.configure do |config|
  config.mock_with(:mocha)
end