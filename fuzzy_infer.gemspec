# -*- encoding: utf-8 -*-
require File.expand_path('../lib/fuzzy_infer/version', __FILE__)

Gem::Specification.new do |gem|
  gem.authors       = ["Seamus Abshere"]
  gem.email         = ["seamus@abshere.net"]
  gem.description   = %q{TODO: Write a gem description}
  gem.summary       = %q{TODO: Write a gem summary}
  gem.homepage      = ""

  gem.executables   = `git ls-files -- bin/*`.split("\n").map{ |f| File.basename(f) }
  gem.files         = `git ls-files`.split("\n")
  gem.test_files    = `git ls-files -- {test,spec,features}/*`.split("\n")
  gem.name          = "fuzzy_infer"
  gem.require_paths = ["lib"]
  gem.version       = FuzzyInfer::VERSION
  
  gem.add_runtime_dependency 'activesupport', '>=3'
  gem.add_runtime_dependency 'activerecord', '>=3'
  gem.add_runtime_dependency 'hashie'
end
