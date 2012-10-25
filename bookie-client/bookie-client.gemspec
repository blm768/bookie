# -*- encoding: utf-8 -*-
lib = File.expand_path('../lib', __FILE__)
$LOAD_PATH.unshift(lib) unless $LOAD_PATH.include?(lib)
require 'bookie-client/version'

Gem::Specification.new do |gem|
  gem.name          = "bookie-client"
  gem.version       = Bookie::LinuxClient::VERSION
  gem.authors       = ["Ben Merritt"]
  gem.email         = ["blm768@gmail.com"]
  gem.description   = %q{Bookie client tools}
  gem.summary       = %q{Bookie client tools}
  gem.homepage      = "https://github.com/blm768/bookie/"

  gem.files         = `git ls-files`.split($/)
  gem.executables   = gem.files.grep(%r{^bin/}).map{ |f| File.basename(f) }
  gem.test_files    = gem.files.grep(%r{^(test|spec|features)/})
  gem.require_paths = ["lib"]
  
  gem.add_dependency('pacct')

  gem.add_development_dependency('rspec')
end
