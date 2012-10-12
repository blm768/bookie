# -*- encoding: utf-8 -*-
require File.expand_path('../lib/bookie-torque_client/version', __FILE__)

Gem::Specification.new do |gem|
  gem.authors       = ["Ben Merritt"]
  gem.email         = ["blm768@gmail.com"]
  gem.description   = %q{Bookie client for TORQUE clusters}
  gem.summary       = %q{Bookie client for TORQUE clusters}
  gem.homepage      = "https://github.com/blm768/bookie/"

  gem.files         = `git ls-files`.split($\)
  gem.executables   = gem.files.grep(%r{^bin/}).map{ |f| File.basename(f) }
  gem.test_files    = gem.files.grep(%r{^(spec|snapshot)/})
  gem.name          = "bookie-torque_client"
  gem.require_paths = ["lib"]
  gem.version       = Bookie::TorqueClient::VERSION
  
  gem.add_dependency('bookie')
  gem.add_dependency('torque_stats')
end
