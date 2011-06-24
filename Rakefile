require 'rubygems'
require 'bundler'
Bundler.setup(:default, :development)
require 'rake'

require 'rspec/core/rake_task'
RSpec::Core::RakeTask.new(:spec)
task :default => :spec

require 'jeweler'
Jeweler::Tasks.new do |gem|
  # gem is a Gem::Specification... see http://docs.rubygems.org/read/chapter/20 for more options
  gem.name = "cucumber-chef"
  gem.homepage = "http://cucumber-chef.org"
  gem.license = "Apache v2"
  gem.summary = "Tests Chef-built infrastructure"
  gem.description = "Framework for behaviour-drive infrastructure development."
  gem.email = "stephen@atalanta-systems.com"
  gem.authors = ["Stephen Nelson-Smith"]
  gem.has_rdoc = false
  gem.bindir = "bin"
  gem.files = `git ls-files`.split("\n")
  gem.executables = %w(cucumber-chef)
end
Jeweler::RubygemsDotOrgTasks.new

require 'rcov/rcovtask'
Rcov::RcovTask.new do |test|
  test.libs << 'test'
  test.pattern = 'test/**/test_*.rb'
  test.verbose = true
end
