require 'rubygems'
require 'rake'

begin
  require 'jeweler'

  Jeweler::Tasks.new do |gem|
    gem.name        = 'woot_sync'
    gem.summary     = %Q{WootSync is a library with common methods for interacting with Woot.com.}
    gem.description = %Q{WootSync is a library with common methods for interacting with Woot.com.}

    gem.email       = 'jtcalhoun@tacostadium.com'
    gem.homepage    = 'http://wootspy.com'
    gem.authors     = ['Jason T. Calhoun']

    gem.add_dependency 'activesupport', '3.0.0'
    gem.add_dependency 'mechanize', '1.0.0'

    gem.add_development_dependency 'shoulda', '>= 0'
  end

rescue LoadError
  puts 'Jeweler (or a dependency) not available. Install it with: gem install jeweler'
end

require 'rake/testtask'

Rake::TestTask.new(:test) do |test|
  test.libs << 'lib' << 'test'
  test.pattern = 'test/**/*_test.rb'
  test.verbose = true
end

task :test    => :check_dependencies
task :default => :test

namespace :doc do

  begin
    require 'yard'
    require 'yard/rake/yardoc_task'

    YARD::Rake::YardocTask.new(:yard) do |doc|
      doc.files   = %w(lib/**/*.rb README.rdoc)
      doc.options = %W(--output-dir doc/yard --readme README.rdoc)
    end

  rescue LoadError
    desc 'Build the YARD HTML Files'
    task :yard do
      abort 'Please install the YARD gem to generate documentation.'
    end
  end
end
