# -*- encoding: utf-8 -*-
$:.push File.expand_path("../lib", __FILE__)
require "ahora/version"

Gem::Specification.new do |s|
  s.name        = "ahora"
  s.version     = Ahora::VERSION
  s.platform    = Gem::Platform::RUBY
  s.authors     = ["Matthijs Langenberg"]
  s.email       = ["matthijs.langenberg@nedap.com"]
  s.homepage    = ""
  s.summary     = %q{Consume Java-ish XML HTTP Resources easily}
  s.description = %q{Consume Java-ish XML HTTP Resources easily}
  s.license     = 'MIT'

  s.files         = `git ls-files`.split("\n")
  s.test_files    = `git ls-files -- {test}/*`.split("\n")
  #s.executables   = `git ls-files -- bin/*`.split("\n").map{ |f| File.basename(f) }
  s.require_paths = ["lib"]

  s.add_dependency "nibbler", '>= 1.3.0'
  s.add_dependency "faraday", '>= 0.7'
  s.add_dependency "nokogiri", "~> 1.5"
  s.add_dependency "activesupport"

  s.add_development_dependency "fakeweb"
  s.add_development_dependency "minitest"
end
