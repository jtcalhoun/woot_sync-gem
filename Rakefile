require 'bundler'
Bundler::GemHelper.install_tasks

namespace :doc do
  require 'yard'
  require 'yard/rake/yardoc_task'

  YARD::Rake::YardocTask.new(:yard) do |doc|
    doc.files   = %w(lib/**/*.rb)
    doc.options = %W(--output-dir doc/yard --files LICENSE --readme README.md)
  end

  task :app => 'doc:yard'
end
