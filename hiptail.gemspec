# coding: utf-8
lib = File.expand_path('../lib', __FILE__)
$LOAD_PATH.unshift(lib) unless $LOAD_PATH.include?(lib)
require 'hiptail/version'

Gem::Specification.new do |spec|
  spec.name          = "hiptail"
  spec.version       = HipTail::VERSION
  spec.authors       = ["ITO Nobuaki"]
  spec.email         = ["daydream.trippers@gmail.com"]
  spec.summary       = %q{Hipchat add-on framework}
  spec.description   = %q{Hipchat add-on framework}
  spec.homepage      = "https://github.com/dayflower/hiptail"
  spec.license       = "MIT"

  spec.files         = %w[
    Gemfile
    LICENSE.txt
    README.md
    Rakefile
    hiptail.gemspec
    lib/hiptail.rb
    lib/hiptail/version.rb
  ]
  spec.executables   = spec.files.grep(%r{^bin/}) { |f| File.basename(f) }
  spec.test_files    = spec.files.grep(%r{^(test|spec|features)/})
  spec.require_paths = ["lib"]

  spec.add_development_dependency "bundler", "~> 1.7"
  spec.add_development_dependency "rake", "~> 10.0"
end
