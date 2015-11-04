require "bundler/gem_tasks"
require "rspec/core/rake_task"

RSpec::Core::RakeTask.new(:spec)

task :default => :spec

task :env do
  require 'metapage'
end

desc "Generates examples for the readme on the fly"
task examples: :env do
  require 'pp'
  cmd = "pp Metapage.fetch('https://github.com/colszowka/simplecov').to_h"
  puts cmd
  eval cmd
end