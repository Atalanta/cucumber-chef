#require "rubygems"
#require "bundler"
#Bundler.setup(:default, :development)
#require "rake"

require "bundler/gem_tasks"
require "rspec/core/rake_task"

RSpec::Core::RakeTask.new(:spec)

task :default => :spec
task :test => :spec

require "cucumber/rake/task"
Cucumber::Rake::Task.new(:cucumber)

require "simplecov"
desc "Run RSpec with code coverage"
task :coverage do
  `rake spec COVERAGE=true`
  `open coverage/index.html`
end
