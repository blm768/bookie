# -*- encoding: utf-8 -*-
lib = File.expand_path('../lib', __FILE__)
$LOAD_PATH.unshift(lib) unless $LOAD_PATH.include?(lib)
require 'pacct/version'

Gem::Specification.new do |gem|
  gem.name          = "pacct"
  gem.version       = Pacct::VERSION
  gem.authors       = ["Ben Merritt"]
  gem.email         = ["blm768@gmail.com"]
  gem.description   = %q{A C extension library for parsing accounting files in the format of /var/account/pacct}
  gem.summary       = %q{A C extension library for parsing accounting files in the format of /var/account/pacct}
  gem.homepage      = "https://github.com/blm768/bookie"
  gem.extensions    = ["ext/pacct/extconf.rb"]

  gem.files         = `git ls-files`.split($/)
  gem.executables   = gem.files.grep(%r{^bin/}).map{ |f| File.basename(f) }
  gem.test_files    = gem.files.grep(%r{^(test|spec|features)/})
  gem.require_paths = ["lib"]
end
