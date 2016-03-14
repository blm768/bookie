# -*- encoding: utf-8 -*-
require File.expand_path('../lib/bookie/version', __FILE__)

Gem::Specification.new do |gem|
  gem.authors       = ["Ben Merritt"]
  gem.email         = ["blm768@gmail.com"]
  gem.license       = "MIT"
  gem.description   = %q{A simple system to consolidate and analyze process accounting records}
  gem.summary       = %q{A simple system to consolidate and analyze process accounting records}
  gem.homepage      = "https://github.com/blm768/bookie/"

  gem.files         = `git ls-files`.split($\)
  gem.executables   = gem.files.grep(%r{^bin/}).map{ |f| File.basename(f) }
  gem.test_files    = gem.files.grep(%r{^(spec)/})
  gem.name          = "bookie_accounting"
  gem.require_paths = ["lib"]
  gem.version       = Bookie::VERSION

  gem.add_dependency('activerecord', '~> 4.2')
  gem.add_dependency('json', '~> 1.8')
  gem.add_dependency('pacct', '>= 0.8.4')
end

