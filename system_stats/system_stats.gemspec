# -*- encoding: utf-8 -*-
lib = File.expand_path('../lib', __FILE__)
$LOAD_PATH.unshift(lib) unless $LOAD_PATH.include?(lib)
require 'system_stats/version'

Gem::Specification.new do |gem|
  gem.name          = "system_stats"
  gem.version       = SystemStats::VERSION
  gem.authors       = ["Ben Merritt"]
  gem.email         = ["blm768@gmail.com"]
  gem.description   = %q{A simple library to obtain basic system information}
  gem.summary       = %q{A simple library to obtain basic system information}
  gem.homepage      = "https://github.com/blm768/bookie"

  gem.files         = `git ls-files`.split($/)
  gem.executables   = gem.files.grep(%r{^bin/}).map{ |f| File.basename(f) }
  gem.extensions    = ["ext/system_stats/extconf.rb"]
  gem.test_files    = gem.files.grep(%r{^(test|spec|features)/})
  gem.require_paths = ["lib"]
  
  gem.add_development_dependency('rspec')
end
