# -*- encoding: utf-8 -*-
require File.expand_path('../lib/bookie/version', __FILE__)

Gem::Specification.new do |gem|
  gem.authors       = ["Ben Merritt"]
  gem.email         = ["blm768@gmail.com"]
  gem.license       = "MIT"
  gem.description   = %q{A simple system to record and query process accounting records}
  gem.summary       = %q{A simple system to record and query process accounting records}
  gem.homepage      = "https://github.com/blm768/bookie/"

  gem.files         = `git ls-files`.split($\)
  gem.executables   = gem.files.grep(%r{^bin/}).map{ |f| File.basename(f) }
  gem.test_files    = gem.files.grep(%r{^(spec)/})
  gem.name          = "bookie_accounting"
  gem.require_paths = ["lib"]
  gem.version       = Bookie::VERSION
  
  gem.add_dependency('activerecord')
  gem.add_dependency('json')
  #For some reason, this is needed when using Bundler.
  #To do: remove when no longer needed
  gem.add_dependency('mysql2')
  gem.add_dependency('pacct')
  gem.add_dependency('spreadsheet')
  gem.add_development_dependency('mocha')
  gem.add_development_dependency('rspec')
  gem.add_development_dependency('sqlite3')
end
