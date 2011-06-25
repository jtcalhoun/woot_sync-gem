# -*- encoding: utf-8 -*-
require File.expand_path('../lib/woot_sync/version', __FILE__)

Gem::Specification.new do |s|
  s.name        = 'woot_sync'
  s.version     = WootSync::VERSION::STRING
  s.platform    = Gem::Platform::RUBY
  s.authors     = ['J T Calhoun']
  s.email       = ['jtcalhoun@tacostadium.com']
  s.homepage    = 'http://wootspy.com'
  s.summary     = 'WootSync is a library with common methods for interacting with Woot.com.'
  s.description = 'WootSync is a library with common methods for interacting with Woot.com.'

  s.required_rubygems_version = '>= 1.3.6'
  s.rubyforge_project         = 'woot_sync-gem'

  s.add_runtime_dependency 'activesupport', '~> 3'
  s.add_runtime_dependency 'em-http-request', '>= 1.0.0.beta.4'
  s.add_runtime_dependency 'htmlentities', '4.3.0'

  s.add_development_dependency 'shoulda', '>= 0'

  s.files        = `git ls-files`.split("\n")
  s.executables  = `git ls-files`.split("\n").map{|f| f =~ /^bin\/(.*)/ ? $1 : nil}.compact
  s.require_path = 'lib'
end
