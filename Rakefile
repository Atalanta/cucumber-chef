require 'rubygems'
require 'bundler'
begin
  Bundler.setup(:default, :development)
rescue Bundler::BundlerError => e
  $stderr.puts e.message
  $stderr.puts "Run `bundle install` to install missing gems"
  exit e.status_code
end
require 'rake'

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

require 'rake/testtask'
Rake::TestTask.new(:test) do |test|
  test.libs << 'lib' << 'test'
  test.pattern = 'test/**/test_*.rb'
  test.verbose = true
end

require 'rcov/rcovtask'
Rcov::RcovTask.new do |test|
  test.libs << 'test'
  test.pattern = 'test/**/test_*.rb'
  test.verbose = true
end

task :default => :test

require 'rdoc/task'
Rake::RDocTask.new do |rdoc|
  version = File.exist?('VERSION') ? File.read('VERSION') : ""

  rdoc.rdoc_dir = 'rdoc'
  rdoc.title = "cucumber-chef #{version}"
  rdoc.rdoc_files.include('README*')
  rdoc.rdoc_files.include('lib/**/*.rb')
end
