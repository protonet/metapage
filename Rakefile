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

  [
    'https://github.com/colszowka/metapage',
    'https://s-media-cache-ak0.pinimg.com/736x/e3/ce/b3/e3ceb3fe3224e104ad0f019117b8e1f0.jpg'
  ].each do |url|

    cmd = "pp Metapage.fetch(#{url.inspect}).to_h"
    puts cmd
    eval cmd

  end
end