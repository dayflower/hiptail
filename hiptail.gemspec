# coding: utf-8
lib = File.expand_path('../lib', __FILE__)
$LOAD_PATH.unshift(lib) unless $LOAD_PATH.include?(lib)
require 'hiptail/version'

Gem::Specification.new do |spec|
  spec.name          = "hiptail"
  spec.version       = HipTail::VERSION
  spec.authors       = ["ITO Nobuaki"]
  spec.email         = ["daydream.trippers@gmail.com"]
  spec.summary       = %q{HipChat Integration (Add-on) Framework}
  spec.description   = %q{HipChat Integration (Add-on) Framework}
  spec.homepage      = "https://github.com/dayflower/hiptail"
  spec.license       = "MIT"

  spec.files         = %w[
    hiptail.gemspec
    README.md
    LICENSE.txt
    CHANGELOG.md
    Gemfile
    Rakefile
    lib/hiptail.rb
    lib/hiptail/atom.rb
    lib/hiptail/authority.rb
    lib/hiptail/authority/provider.rb
    lib/hiptail/authority/sqlite3_provider.rb
    lib/hiptail/event.rb
    lib/hiptail/manager.rb
    lib/hiptail/web/handler.rb
    lib/hiptail/web/rack_app.rb
    lib/hiptail/util.rb
    lib/hiptail/version.rb
    examples/simple_rack_app_1/Gemfile
    examples/simple_rack_app_1/config.ru
    examples/simple_rack_app_1/README.md
    examples/simple_rack_app_2/Gemfile
    examples/simple_rack_app_2/app.rb
    examples/simple_rack_app_2/config.ru
    examples/simple_rack_app_2/README.md
    examples/integrate_sinatra/Gemfile
    examples/integrate_sinatra/app.rb
    examples/integrate_sinatra/README.md
  ]
  spec.executables   = spec.files.grep(%r{^bin/}) { |f| File.basename(f) }
  spec.test_files    = spec.files.grep(%r{^(test|spec|features)/})
  spec.require_paths = ["lib"]

  spec.add_dependency "rack"
  spec.add_dependency "oauth2"

  spec.add_development_dependency "bundler", "~> 1.7"
  spec.add_development_dependency "rake", "~> 10.0"
end
