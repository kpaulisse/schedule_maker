require 'rubygems'
require 'bundler/setup'

require 'bundler'
Bundler::GemHelper.install_tasks

task :default do
  Rake::Task['spec'].invoke
end

desc "Run all schedule_maker gem specs"
task :spec do
  # Run plain rspec command without RSpec::Core::RakeTask overrides.
  exec "rspec -c spec"
end
