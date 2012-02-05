# -*- encoding: utf-8 -*-
$:.push File.expand_path("../lib", __FILE__)
require "woot_sync/version"

Gem::Specification.new do |s|
  s.name        = "woot_sync"
  s.version     = WootSync::VERSION::STRING
  s.authors     = ["J T Calhoun"]
  s.email       = ["jtcalhoun@tacostadium.com"]
  s.homepage    = "http://wootspy.com"
  s.summary     = "WootSync is a library with common methods for interacting with Woot.com."
  s.description = "WootSync is a library with common methods for interacting with Woot.com."

  s.rubyforge_project = "woot_sync-gem"

  s.add_runtime_dependency "activesupport", "~> 3"
  s.add_runtime_dependency "em-http-request", ">= 1.0.1"
  s.add_runtime_dependency "htmlentities", ">= 4.3.0"
  s.add_runtime_dependency "yajl-ruby"

  s.add_development_dependency "shoulda", ">= 0"

  s.files         = `git ls-files`.split("\n")
  s.test_files    = `git ls-files -- {test,spec,features}/*`.split("\n")
  s.executables   = `git ls-files -- bin/*`.split("\n").map{ |f| File.basename(f) }
  s.require_paths = ["lib"]
end

